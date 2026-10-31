# agent-base

Shared base image for the AI coding-agent containers in this workspace
(`claude-code`, `opencode`, `deepseek-harness`). It exists so those three stop
carrying three drifting copies of the same sandbox.

What it provides:

- **Debian 12**, pinned by digest, with **Node/npm from Debian's own packages**
  (18.20 / npm 9.2 on bookworm). Not Alpine: agent CLIs ship glibc-only native
  builds (dsh refuses to boot on musl), so glibc is the only base all three
  run on. The Node version is the one caveat: dsh's `engines` require
  `^22.19.0 || >=24`, so a dsh child must bring its own Node (NodeSource apt
  repo, a pinned tarball, or the upstream node image) — this base only installs
  from package managers, and Debian ships 18.20.
- **One unprivileged user** (`agent`, uid/gid 1000 by default), owning its home
  and working directory, so bind mounts line up with the host user.
- **A rootless Docker daemon** started by the entrypoint — `docker` works
  inside the container without `--privileged`.
- **Python 3 + uv, yq, git/gh, a native build toolchain**, the GNU userland and
  the CLI utilities agents assume are installed. Everything userland-facing
  comes from a package manager: `yq` from Debian (kislyuk's 3.x, a jq wrapper —
  not mikefarah's v4, which Debian doesn't ship), `uv` from PyPI via `pipx`
  (Debian has no `uv` package in any suite).
- **A generic entrypoint** with a hook directory, and a healthcheck.

It deliberately contains **no agent CLI**. Each child image installs its own
CLI, its config and its default command on top.

## Use it

```dockerfile
FROM git.omesa.net/asemo/agent-base:1

ARG CLAUDE_VERSION=2.1.3
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "${CLAUDE_VERSION}"

COPY hooks/ /etc/agent-entrypoint.d/
ENV AGENT_CMD=claude
```

and, in the child's `docker-compose.yml`:

```yaml
services:
  claude:
    extends:
      file: ../agent-base/compose.base.yml
      service: agent-base
    image: claude-code:local
    build:
      context: .
      dockerfile: Dockerfile
    command: ["--remote-control"]
    volumes:
      - ${CLAUDE_HOME_HOST:-claude-home}:/home/agent/.claude
volumes:
  claude-docker:   # required: compose.base.yml mounts ${AGENT_DOCKER_VOLUME}
```

Notes for child images:

- `compose.base.yml` writes mount targets as `/home/${AGENT_USER}`, which is
  `/home/agent` unless the child renames the account (next section).
- A child that needs to translate env vars into CLI flags (dsh's `DSH_PORT` →
  `--port`) ships a hook in `/etc/agent-entrypoint.d/` instead of forking the
  entrypoint. Hooks are sourced and may rewrite `$@`; see
  [rootfs/etc/agent-entrypoint.d/README](rootfs/etc/agent-entrypoint.d/README).
- A child with a real readiness signal should override `HEALTHCHECK`
  (dsh signs a session cookie and requires HTTP 200; opencode can probe its
  web UI). The default here checks that `AGENT_CMD` is alive and warns when the
  daemon is down.

## Account name

The account is **`agent`**, and keeping it is the zero-boilerplate path: one
home path (`/home/agent`) across every stack, which is exactly the "everyone
follows the same thing" property this base exists for.

`AGENT_USER` is a build arg, but changing it on a child does **not** rename
anything by itself — `FROM` cannot retroactively change the base image's user.
A child that insists on its own account name must do it in its own layer. This
recipe is verified end to end:

```dockerfile
FROM agent-base:1
ARG AGENT_USER=claude
USER root
RUN set -e; \
    groupmod --new-name "${AGENT_USER}" agent; \
    usermod --login "${AGENT_USER}" --home "/home/${AGENT_USER}" --move-home --shell /bin/bash agent; \
    sed -i "/^agent:/d" /etc/subuid /etc/subgid; \
    printf '%s:100000:65536\n' "${AGENT_USER}" >> /etc/subuid; \
    printf '%s:100000:65536\n' "${AGENT_USER}" >> /etc/subgid
USER 1000:1000
# Every one of these embeds the old home path and must move with the account,
# otherwise the container recreates /home/agent root-owned and the daemon
# socket points at the wrong place.
WORKDIR /home/claude/Projects
ENV HOME=/home/claude \
    AGENT_USER=claude \
    AGENT_WORKSPACE=/home/claude/Projects \
    XDG_RUNTIME_DIR=/home/claude/.docker/run \
    DOCKER_HOST=unix:///home/claude/.docker/run/docker.sock
```

## Hosts with a rootless outer Docker

The image needs to create a user namespace for its own rootless daemon. When
the host's Docker daemon is **itself** rootless, two consequences apply:

- Bind mounts from the host appear **root-owned** inside the container, so a
  directory owned by uid 1000 on the host is not writable by `agent`
  (uid 1000); `agent-entrypoint` stops with an ownership error instead of a
  confusing `EACCES` later. Use a named volume, a world-writable directory, or
  a rootful outer daemon.
- The nested daemon cannot start at all (`newuidmap: write to uid_map failed:
  Operation not permitted`). The entrypoint logs that and still starts the
  CLI; the agent works, only `docker` inside it is unavailable. This is the
  case in the DSH sandbox this image was built in, so `make smoke` reports the
  daemon step as SKIP there — run it on a rootful host (or with
  `SMOKE_REQUIRE_DOCKER=1` where dockerd is expected to work) to test it fully.

## Contract

### Environment

| Variable | Default | Meaning |
|---|---|---|
| `AGENT_CMD` | `bash` | CLI the entrypoint exec's with the container's args |
| `AGENT_WORKSPACE` | `$HOME/Projects` | working directory; must be writable |
| `AGENT_DOCKERD` | `1` | start the rootless daemon (`0` skips it) |
| `AGENT_DOCKERD_TIMEOUT` | `30` | seconds to wait for the daemon socket |
| `AGENT_HEALTHCHECK` | `auto` | `auto`, `docker`, `agent`, `url:<url>`, `off` |
| `AGENT_HEALTH_URL` | – | extra URL that must answer successfully |
| `XDG_RUNTIME_DIR` | `$HOME/.docker/run` | daemon socket directory |
| `DOCKER_HOST` | `unix://$XDG_RUNTIME_DIR/docker.sock` | daemon socket |

`AGENT_HEALTHCHECK=auto` (the default) fails when `AGENT_CMD` is not running or
`AGENT_HEALTH_URL` does not answer; a rootless daemon that is down is logged as
a warning, because the agent still works without it (see the section above).
Use `docker` to make the daemon mandatory.

### Filesystem

| Path | Purpose |
|---|---|
| `/home/<AGENT_USER>/Projects` | working directory (`AGENT_WORKSPACE`) |
| `/home/<AGENT_USER>/.local/share/docker` | rootless daemon data root (own volume) |
| `/home/<AGENT_USER>/.docker/dockerd.log` | daemon log |
| `/etc/agent-entrypoint.d/*.sh` | sourced hooks, run before the CLI starts |
| `/usr/local/lib/agent-base/selftest.sh` | in-container validation |

### Runtime requirements

The daemon needs the container started with `seccomp:unconfined`,
`systempaths=unconfined`, `/dev/fuse` and `/dev/net/tun`; `compose.base.yml`
sets all of them. Without them the container still runs and the agent still
works — only `docker` is unavailable, and the entrypoint logs why.

## Build and test

```bash
make build     # bake.sh → agent-base:latest + :1.0.0, OCI labels from git
make test      # build-time: shellcheck + tool matrix (no daemon)
make smoke     # real container: tools, healthcheck, daemon when possible
make up        # keep a harness container around for poking at
make debug     # root shell in it
```

The image is built from `rootfs/` plus the `Dockerfile`; everything else in
this directory is host tooling (see `.dockerignore`).

## Layout

| File | Purpose |
|---|---|
| `Dockerfile` | the image; `test` stage runs shellcheck + selftest |
| `docker-bake.hcl` | bake targets, pinned versions, OCI labels |
| `bake.sh` | wraps bake and injects `GIT_SHA`/`GIT_REF` |
| `compose.base.yml` | shared service definition children `extends` |
| `docker-compose.yml` | test harness for the base itself |
| `rootfs/` | entrypoint, healthcheck, selftest, hook directory |
| `scripts/smoke.sh` | runtime validation in a real container |
