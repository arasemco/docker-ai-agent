# agent-base

A generic, reusable base image for AI coding-agent containers.

It packages the parts every agent image otherwise re-implements — a glibc
distro with Node, one unprivileged user, a rootless Docker daemon under s6
supervision, Python/uv and a dev toolchain — and nothing else. It contains no
agent: a child image adds its own CLI in a handful of lines.

Nothing in the core is specific to the author's machine: no registry, no proxy,
no host paths, no resource limits, no author metadata.

## Quick start

```bash
# build the image (pinned versions, OCI labels from git)
make build

# build-time checks: shellcheck on every script + a tool-matrix selftest
make test

# run it for real: both s6 services, storage driver, a real image build
make smoke
```

Or without the makefile:

```bash
docker compose up -d --build     # root file: base + daemon + image
scripts/bake.sh                  # build the image via bake
```

## Using it from a child image

```dockerfile
# my-agent/Dockerfile
FROM agent-base:1.2.0

RUN npm install --global "my-agent-cli@1.2.3"
RUN install -d -o 1000 -g 1000 /home/agent/.config/my-agent-cli
ENV AGENT_CMD=my-agent-cli
# COPY hooks/ /etc/agent-entrypoint.d/     # optional, see "Hooks"
```

```yaml
# my-agent/docker-compose.yml — just the agent-specific bits
services:
  my-agent:
    image: my-agent:local
    build:
      context: ./image
      args:
        AGENT_BASE: agent-base:1.2.0
    command: ["--help"]                  # args for AGENT_CMD
    volumes:
      - my-agent-home:/home/agent/.config/my-agent-cli
volumes:
  agent-docker:                          # required by compose/base.yml
  my-agent-home:
```

```bash
# the sandbox comes from the fragments; --service renames them onto "my-agent"
../agent-base/scripts/compose.sh --service my-agent \
    --fragments ../agent-base/compose --file docker-compose.yml -- up -d --build
```

A complete, runnable version of this lives in
[examples/child-image](examples/child-image).

Do **not** end a child image with `USER 1000:1000`: `/init` must be PID 1 as
root so it can prepare `/run`, fix mount-point ownership and drop privileges per
service. The CLI itself still runs as the agent user.

## Compose fragments

`compose/` holds one fragment per concern, not one monolith. Each file owns
exactly one thing:

| Fragment | Owns | Included by |
|---|---|---|
| `base.yml` | service skeleton + `AGENT_*` toggles | always |
| `daemon.yml` | `/dev/fuse`, `/dev/net/tun`, seccomp exceptions, `agent-docker` volume | `--with daemon` (default) |
| `image.yml` | build of `image/` (no command, no mounts — the stack decides) | the root file and `make` |
| `harness.yml` | keeps the sandbox container alive for `make exec`/smoke | `make`, `scripts/smoke.sh` |
| `proxy.yml` | outbound proxy: `HTTP_PROXY` → `http_proxy` → `PROXY` → empty (no values baked in) | `--with proxy` |
| `limits.yml` | CPU/memory from `AGENT_CPUS` / `AGENT_MEMORY` | `--with limits` |
| `mounts.yml` | bind the workspace to `AGENT_WORKSPACE_HOST` (default `./workspace`) | `--with mounts` |

The root [docker-compose.yml](docker-compose.yml) is the minimal working stack:
it `include:`s `base`, `daemon` and `image`, so nothing is copied or kept in
sync by hand.

```bash
docker compose up -d --build                              # base + daemon + image
docker compose exec --user 1000 agent-base bash

scripts/compose.sh --with daemon,proxy --file compose/image.yml -- up -d   # + proxy
make up WITH=daemon,proxy,limits                          # + limits, via make
```

Fragments are written for the canonical service name `agent-base`. When a child
stack asks for another name, `compose.sh` renames the key in a throwaway copy —
`-f` merging only lines up services that share a name, and compose accepts only
a single `extends` per service, so stacking fragments that way is not possible.

Compose resolves relative paths against the project directory, which it infers
from the first file it is given. `compose.sh` anchors that to the directory of
the `--file` stack, so `context: ./image` means "this repo's image/" for a child
and `context: ../image` means the same for agent-base's own `compose/image.yml`.

Anything beyond the fragments (extra binds, per-host tweaks) goes in a
gitignored `compose/local.yml`, which `compose.sh` appends automatically.

## What is inside

- **Debian 12 (glibc)**, pinned by digest, with Node/npm from Debian's own
  packages. Alpine is deliberately not used: agent CLIs commonly ship
  glibc-only native builds. Bookworm ships Node 18.20 — a CLI that needs a
  newer Node installs it itself (the base only uses package managers).
- **One unprivileged user** (`agent`, uid/gid 1000), owning its home, so bind
  mounts line up with the host user on most systems.
- **s6-overlay as PID 1** supervising two independent longruns: `dockerd` (the
  rootless Docker daemon, so `docker` works without `--privileged`) and `agent`
  (the CLI). They restart independently, the daemon reports readiness through
  s6's notification fd, and repeated failed starts back off instead of looping.
- **Python 3 + uv, yq, git/gh, a native build toolchain**, the GNU userland and
  the CLI utilities agents assume exist — all from a package manager (`yq` from
  Debian, `uv` from PyPI via `pipx`, since Debian does not package uv).
- **An entrypoint wrapper**, a hook directory and a healthcheck.

## Contract

### Services (s6-overlay)

`/init` is PID 1. Two legacy-style longruns start after the
[cont-init scripts](image/rootfs/etc/cont-init.d):

| Service | Runs as | What it does |
|---|---|---|
| `dockerd` | `AGENT_USER` | rootless Docker daemon; announces readiness on s6's notification fd once `docker info` answers |
| `agent` | `AGENT_USER` | waits (bounded) for `dockerd` readiness, then execs `AGENT_CMD` |

Restart policy:

- `dockerd` restarts on any exit; after `AGENT_DOCKERD_MAX_RESTARTS` (3)
  failed starts in a row it is left down and the service idles instead of
  restart-looping. A run of 60 s or more resets the counter.
- `agent` stops the container when the CLI exits **0**; a non-zero exit after
  60 s restarts it with a fresh counter, and `AGENT_RESTART_MAX` (3) failed
  starts in a row stop the container. A signal (container stop) never restarts.

Because the CLI is a supervised service and not PID 1, **the container's exit
status is s6's** (0). The CLI's status is recorded in `/run/agent/exit-code`
and logged.

### Environment

| Variable | Default | Meaning |
|---|---|---|
| `AGENT_CMD` | `bash` | CLI the agent service runs |
| `AGENT_WORKSPACE` | `$HOME/workspace` | working directory; must be writable |
| `AGENT_DOCKERD` | `1` | start the rootless daemon (`0` skips it) |
| `AGENT_DOCKERD_TIMEOUT` | `30` | seconds to wait for daemon readiness |
| `AGENT_DOCKERD_MAX_RESTARTS` | `3` | consecutive failed daemon starts before idling |
| `AGENT_RESTART_MAX` | `3` | consecutive failed CLI starts before stopping the container |
| `AGENT_HEALTHCHECK` | `auto` | `auto`, `docker`, `agent`, `url:<url>`, `off` |
| `AGENT_HEALTH_URL` | – | extra URL that must answer successfully |
| `AGENT_USER` | `agent` | account the services run as (build arg + env) |
| `XDG_RUNTIME_DIR` | `$HOME/.docker/run` | daemon socket directory |
| `DOCKER_HOST` | `unix://$XDG_RUNTIME_DIR/docker.sock` | daemon socket |

`AGENT_HEALTHCHECK=auto` fails when `AGENT_CMD` is not running or
`AGENT_HEALTH_URL` does not answer; a rootless daemon that is down is only
warned about, because the agent still works without it. Use `docker` to make
the daemon mandatory.

### Filesystem

| Path | Purpose |
|---|---|
| `/home/<AGENT_USER>/workspace` | working directory (`AGENT_WORKSPACE`) |
| `/home/<AGENT_USER>/.local/share/docker` | rootless daemon data root (own volume) |
| `/home/<AGENT_USER>/.docker/dockerd.log` | daemon log |
| `/run/agent/args` | container CMD, NUL-separated (written by the entrypoint) |
| `/run/agent/exit-code` | last CLI exit status |
| `/run/agent/*.fails` | restart counters (delete to retry after giving up) |
| `/etc/agent-entrypoint.d/*.sh` | hooks, sourced before the CLI starts |
| `/etc/cont-init.d/`, `/etc/services.d/` | s6 stage-2 scripts and services |
| `/usr/local/lib/agent-base/selftest.sh` | in-container validation |

### Hooks

A child can drop `*.sh` files into `/etc/agent-entrypoint.d/`. They are
**sourced** just before the CLI starts, as the agent user, so they can rewrite
the argument list (`set -- web --no-open "$@"`) or export variables the CLI
reads. They must not fail the start: wrap optional work in `|| true`.

### Runtime requirements

The daemon needs `seccomp:unconfined`, `systempaths=unconfined`, `/dev/fuse`
and `/dev/net/tun`; `compose/base.yml` sets them. Without them the container
still runs and the agent still works — only `docker` is unavailable, and the
daemon service logs why.

`docker exec` lands as **root** (PID 1's user). For the agent's shell:
`docker compose exec --user 1000 <service> bash`.

## Overrides (keep your machine out of git)

The core is generic. Put your own values in files that are **not** tracked, and
start from the examples:

| File (gitignored) | Start from | Holds |
|---|---|---|
| `compose/local.yml` | the fragments, plus your own binds | per-host tweaks beyond the fragments |
| `.env` | `.env.example`, `examples/env/proxy-squid.env` | proxy URLs, limits, volume names, ports |

`compose.sh` merges `compose/local.yml` automatically when it exists, so a
typical setup needs no flags at all:

```bash
cp .env.example .env
cat examples/env/proxy-squid.env >> .env     # only if you need a proxy
echo 'AGENT_CPUS=8' >> .env                  # only if you want limits
echo 'AGENT_MEMORY=32G' >> .env
make up WITH=daemon,proxy,limits
```

Two host-path rules that bite when you add binds of your own: a missing bind
source is auto-created root-owned (the image's cont-init then refuses to start),
and on a host whose Docker is rootless, bind mounts appear root-owned *inside*
the container, so uid 1000 cannot write them.

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | the image; `test` stage runs shellcheck + selftest |
| `image/rootfs/` | files copied into the image: entrypoint, agent-run, healthcheck, selftest, s6 services, cont-init, hooks dir |
| `docker-compose.yml` | the minimal working stack (`include:` of base + daemon + image) |
| `compose/{base,daemon,image,proxy,limits,mounts}.yml` | one fragment per concern (see "Compose fragments") |
| `compose/harness.yml` | test-only overlay: sleep-forever command instead of a shell |
| `scripts/compose.sh` | assembles the fragments, renames the service for a child, merges `compose/local.yml` |
| `examples/` | env examples and a child-image example; not used by the build |
| `docker-bake.hcl` | bake targets, pinned versions, neutral defaults |
| `scripts/bake.sh` | fills the provenance variables from git (see "Publishing") and runs bake from the repo root |
| `scripts/smoke.sh` | runtime validation in a real container |
| `makefile` | `build`, `test`, `smoke`, `up`, `down`, `exec`, `debug`, `config` |

## Publishing

`scripts/bake.sh` fills in the provenance variables from the checkout before
running bake, so an OCI-labelled image needs no hand-typed metadata:

| Variable | Derived from | Example |
|---|---|---|
| `GIT_SHA` | `git rev-parse HEAD` | `3439dfb…` |
| `GIT_REF` | exact tag at HEAD, else branch | `v1.2.0` / `main` |
| `AUTHOR` | author of the last commit | `Jane Roe <jane@example.org>` |
| `SOURCE_URL` | the git remote, normalised to https | `https://git.example/team/agent-base` |
| `REGISTRY` | that remote's host + owner (forge-aware) | `git.example/team`, `ghcr.io/team`, `registry.gitlab.com/team` |
| `VENDOR` | author's mail domain | `example.org` |
| `LICENSES` | SPDX id detected in `LICENSE`/`COPYING` | `MIT` |
| `BASE_VERSION` | the exact tag at HEAD, when it is `vX.Y.Z` | `1.2.0` |

Rules:

- **The environment always wins.** `AUTHOR="…" REGISTRY=… scripts/bake.sh --push`
  overrides anything derived.
- **Which remote** supplies `SOURCE_URL`/`REGISTRY`: `BAKE_REMOTE=<name>` if
  set, else `origin`, else the first configured remote — a repo whose only
  remote is called `gitea` or `upstream` works without renaming it.
- **`--push` requires a registry.** With no `REGISTRY` (derived or explicit)
  bake would tag `agent-base:latest` and push it to Docker Hub's `library/`
  namespace, which fails with a confusing `denied: requested access to the
  resource is denied`. The script refuses up front and prints the three ways
  forward; `BAKE_ALLOW_DOCKERHUB_PUSH=1` is the explicit opt-in.
- **`BAKE_DERIVE=0`** disables derivation entirely (leaves bake's defaults: no
  registry, `unknown` metadata), for a fully manual build.
- **`BAKE_QUIET=1`** silences the one-line summary of what was derived.
- Outside a git checkout (a source tarball) nothing is derived and bake runs on
  its defaults; no `git` noise.

So on a plain clone of this repo the image is tagged locally
(`agent-base:1.2.0`); with a remote set it is tagged for that forge's registry
(`<host>/<owner>/agent-base:1.2.0`). Optional metadata that stays unset renders
as `unknown` in the OCI labels.

Pushing needs credentials for that registry first:

```bash
docker login git.example.com        # or ghcr.io, registry.gitlab.com, …
scripts/bake.sh --push              # tags + push, derived from the remote
```

For a Gitea/Forgejo registry the image path is `<host>/<owner>/<image>`, so a
remote of `https://git.example.com/team/repo.git` yields
`git.example.com/team/agent-base:1.2.0`.
