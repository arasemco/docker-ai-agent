# opencode

The [OpenCode](https://opencode.ai) CLI / Web UI in a container, built on
[agent-base](../agent-base): an s6-supervised sandbox with a rootless Docker
daemon, a dev toolchain and persistent state.

This repo contains only OpenCode. Everything shared — Debian + Node/npm, the
`agent` user, the s6 services, the toolchain, the entrypoint, hooks and the
healthcheck — comes from `agent-base`, pinned by tag in `AGENT_BASE`.

The stack itself carries no host-specific values: no proxy URLs, no host paths,
no CPU/memory numbers. Those live in a gitignored `compose/local.yml` or `.env`,
started from `examples/`.

## Quick start

```bash
cp .env.example .env          # port, image, password
docker compose up -d --build
```

Then open <http://127.0.0.1:4096>. The UI is published on loopback by default
because `OPENCODE_SERVER_PASSWORD` has a weak fallback — set a real password
before setting `OPENCODE_BIND_IP=0.0.0.0`.

`make` wraps the same thing:

```bash
make build      # scripts/bake.sh → image (derived provenance, pinned versions)
make up         # build + start
make smoke      # UI probe, healthcheck, s6 service state, opencode --version
make logs
make exec       # shell as the agent user (uid 1000)
make debug      # shell as root
```

## How it is put together

| Piece | Comes from |
|---|---|
| base image (Debian, agent user, s6 services, dockerd, toolchain) | `AGENT_BASE` build arg, default `agent-base:1.2.0` |
| OpenCode itself | `npm install -g opencode-ai@${OPENCODE_VERSION}` in `image/Dockerfile` |
| sandbox (service skeleton, devices/seccomp, proxy, limits, mounts) | agent-base compose fragments, assembled by `scripts/compose.sh` |
| entrypoint, hooks, healthcheck, restart policy | `agent-base` |
| provider config | yours: see [examples/config/opencode.jsonc](examples/config/opencode.jsonc) |

State lives under `/home/agent`:

| Path | Volume | Holds |
|---|---|---|
| `/home/agent/.config/opencode` | `opencode-config` | providers/models |
| `/home/agent/.local/share/opencode` | `opencode-data` | `auth.json`, session DB, snapshots |
| `/home/agent/.local/state/opencode` | `opencode-state` | XDG state |
| `/home/agent/workspace` | – | working directory (mount something here) |

No config is baked into the image: which providers you have and where they run
is deployment-specific. Either configure providers in the UI (it writes
`auth.json` into the data volume), or seed a config:

```bash
cp examples/config/opencode.jsonc compose/config.jsonc   # edit, then mount it:
# volumes: [ ./compose/config.jsonc:/home/agent/.config/opencode/opencode.jsonc:ro ]
```

## Compose fragments (what gets included)

The stack is assembled from agent-base's per-concern fragments; pick the ones
you need with `WITH` (or `--with`):

| Fragment | `--with` | Adds |
|---|---|---|
| `base` | always | service skeleton, `AGENT_*` toggles, daemon data volume |
| `daemon` | default | `/dev/fuse`, `/dev/net/tun`, `seccomp:unconfined`, `systempaths: unconfined` |
| `proxy` | `proxy` | outbound proxy pass-through (values from `.env`) |
| `limits` | `limits` | CPU/memory limits from `AGENT_CPUS` / `AGENT_MEMORY` |
| `mounts` | `mounts` | bind the workspace to `AGENT_WORKSPACE_HOST` (default `./workspace`) |

```bash
make up                                   # base + daemon
make up WITH=daemon,proxy                 # + proxy
WITH=daemon,limits,mounts make up         # + limits + host mount
./scripts/compose.sh --with daemon,proxy -- up -d    # same, without make
```

`docker-compose.yml` on its own is a valid stack (plain `docker compose up`
works), but it then has no fragment grants: the UI runs fine while the inner
Docker daemon cannot start. Use `make` / `scripts/compose.sh` (or merge the
fragments yourself with `-f`) when you want `docker` inside the container.

## Overrides (keep your machine out of git)

| File (gitignored) | Start from | Holds |
|---|---|---|
| `compose/local.yml` | your own fragment | extra binds, per-host tweaks beyond the fragments |
| `.env` | `.env.example`, `examples/env/*.env` | port, password, provider keys, proxy, limits |

`scripts/compose.sh` merges `compose/local.yml` automatically when it exists:

```bash
cp .env.example .env
cat examples/env/proxy-squid.env >> .env     # only if you need a proxy
cat examples/env/providers.env >> .env       # provider keys / local endpoint
make up WITH=daemon,proxy
```

## Contract with agent-base

- The image runs as root (s6-overlay's `/init` is PID 1) and drops to the
  `agent` user per service; `docker exec` therefore lands as root. Use
  `make exec` (or `--user 1000`) for the agent's shell.
- The container's exit status is s6's; the CLI's status is in
  `/run/agent/exit-code`.
- The healthcheck proves the CLI process is alive and warns when the rootless
  daemon is down (it cannot start when the host's own Docker is rootless).
  It does not probe the HTTP port, because a password-protected UI answers 401
  to a bare request.
- A child image must not end with `USER 1000:1000` — `/init` needs root; see
  `image/Dockerfile`'s note.

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | the OpenCode layer on top of agent-base |
| `docker-compose.yml` | the stack: only OpenCode-specific settings |
| `scripts/compose.sh` | wraps agent-base's assembler: fragments + this stack + `compose/local.yml` |
| `compose/local.yml` | gitignored, machine-specific overrides |
| `examples/` | config, proxy/provider env and compose fragments (copy-paste) |
| `docker-bake.hcl` | bake targets, pinned versions, neutral defaults |
| `scripts/bake.sh` | derives provenance from git (remote, author, licence…) and runs bake |
| `scripts/smoke.sh` | runtime check of the running stack |
| `makefile` | `build`, `up`, `down`, `smoke`, `logs`, `exec`, `debug`, `config` |

## Publishing

```bash
docker login git.example.com
scripts/bake.sh --push     # tags derive from the git remote: <host>/<owner>/opencode
```

`scripts/bake.sh` derives `SOURCE_URL`, `REGISTRY`, `AUTHOR`, `VENDOR`,
`LICENSES`, `GIT_SHA` and `GIT_REF` from the checkout; the environment always
wins (`REGISTRY=… scripts/bake.sh --push`), `BAKE_DERIVE=0` turns it off, and
`--push` without a registry is refused instead of trying Docker Hub. See
[agent-base's README](../agent-base/README.md#publishing) for the full table.
