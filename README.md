# agent-base

A reusable container image for AI coding-agent CLIs, plus the compose pieces to
run it.

It packages what every agent image otherwise re-implements: a glibc distribution
with Node, one unprivileged user, an s6-supervised rootless Docker daemon, and a
development toolchain. It contains no agent — a child image adds its own CLI in a
handful of lines.

The core carries no host-, person- or project-specific values: no registry, no
proxy, no host paths, no resource limits, no author metadata.

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

## Use from a child image

```dockerfile
# my-agent/Dockerfile
FROM agent-base:1.4.0

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
        AGENT_BASE: agent-base:1.4.0
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
| `skills.yml` | bind a shared Agent Skills root to `AGENT_SKILLS_HOST` (default `./skills`, read-only) | `--with skills` |

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
gitignored `compose/local.yml`, which `compose.sh` appends automatically;
[examples/compose/local.yml](examples/compose/local.yml) is a starting point.

## What is inside

- **Debian 12 (glibc)**, pinned by digest, with Node/npm from Debian's own
  packages. Alpine is not used: agent CLIs commonly ship glibc-only native
  builds. Bookworm provides Node 18.20; a CLI that needs a newer Node installs
  it itself, since the base installs only from package managers.
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

## Configuration

Every setting is optional and defaults to something workable. The full table —
including volumes, hooks and healthcheck modes — is in
[docs/configuration.md](docs/configuration.md); the ones used most:

| Variable | Default | Meaning |
|---|---|---|
| `AGENT_CMD` | `bash` | command the `agent` service runs |
| `AGENT_WORKSPACE` | `$HOME/workspace` | working directory |
| `AGENT_DOCKERD` | `1` | `0` keeps the inner daemon down |
| `AGENT_DOCKERD_TIMEOUT` | `30` | seconds to wait for daemon readiness |
| `AGENT_RESTART_MAX` | `3` | failed CLI starts before the container stops |
| `AGENT_HEALTHCHECK` | `auto` | `auto`, `docker`, `agent`, `url:<url>`, `off` |

Two operational details:

- The inner daemon needs `seccomp:unconfined`, `systempaths=unconfined`,
  `/dev/fuse` and `/dev/net/tun` (`compose/daemon.yml`). Without them the agent
  runs but `docker` inside the container does not.
- `docker exec` lands as **root** (s6's PID 1). Use `--user 1000` for a shell
  with the agent's identity.

## Overrides (keep your machine out of git)

The core is generic. Put your own values in files that are **not** tracked, and
start from the examples:

| File (gitignored) | Start from | Holds |
|---|---|---|
| `compose/local.yml` | `examples/compose/local.yml` | per-host tweaks beyond the fragments |
| `.env` | `.env.example`, `examples/env/proxy.env` | proxy URLs, limits, volume names, ports |

`compose.sh` merges `compose/local.yml` automatically when it exists, so a
typical setup needs no flags at all:

```bash
cp .env.example .env
cat examples/env/proxy.env >> .env           # only if you need a proxy
echo 'AGENT_CPUS=8' >> .env                  # only if you want limits
echo 'AGENT_MEMORY=32G' >> .env
make up WITH=daemon,proxy,limits
```

Two host-path rules that bite when you add binds of your own: a missing bind
source is auto-created root-owned (the image's cont-init then refuses to start),
and on a host whose Docker is rootless, bind mounts appear root-owned *inside*
the container, so uid 1000 cannot write them.

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | overview and reading order |
| [docs/architecture.md](docs/architecture.md) | image layout, boot sequence, services, state |
| [docs/compose.md](docs/compose.md) | fragments, assembler, child stacks |
| [docs/configuration.md](docs/configuration.md) | every variable, volume, path and hook |
| [docs/build.md](docs/build.md) | build, provenance, publishing, versioning |
| [docs/troubleshooting.md](docs/troubleshooting.md) | known failure modes |
| [.agents/README.md](.agents/README.md) | working on this repository (map, invariants, checks) |

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | the image; `test` stage runs shellcheck + selftest |
| `image/rootfs/` | files copied into the image: entrypoint, agent-run, healthcheck, selftest, s6 services, cont-init, hooks dir |
| `docker-compose.yml` | the minimal working stack (`include:` of base + daemon + image) |
| `compose/{base,daemon,image,proxy,limits,mounts}.yml` | one fragment per concern (see "Compose fragments") |
| `compose/harness.yml` | test-only overlay: sleep-forever command instead of a shell |
| `scripts/compose.sh` | assembles the fragments, renames the service for a child, merges `compose/local.yml` |
| `examples/` | copy-paste material: proxy env, a local.yml overlay, a child image (see [examples/README.md](examples/README.md)) |
| `docker-bake.hcl` | bake targets, pinned versions, neutral defaults |
| `scripts/bake.sh` | fills the provenance variables from git (see "Publishing") and runs bake from the repo root |
| `scripts/smoke.sh` | runtime validation in a real container |
| `makefile` | `build`, `test`, `smoke`, `up`, `down`, `exec`, `debug`, `config` |

## Publishing

`scripts/bake.sh` derives the provenance metadata from the checkout (commit,
author, remote, licence, version) and tags the image for the remote's registry.
Override any of it from the environment, disable derivation with
`BAKE_DERIVE=0`, and log in before pushing:

```bash
docker login registry.example
scripts/bake.sh --push
```

[docs/build.md](docs/build.md) documents the derivation table, the pinned inputs
and the CI workflow.

## License

MIT — see [LICENSE](LICENSE).
