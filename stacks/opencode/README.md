# opencode

The [OpenCode](https://opencode.ai) CLI and Web UI in a container, built on
[agent-base](../../README.md): an s6-supervised sandbox with a rootless
Docker daemon, a development toolchain and persistent state.

This repository owns only OpenCode. The sandbox — Debian base, the `agent` user,
the s6 services, the toolchain, the entrypoint, hooks and the healthcheck —
comes from agent-base, pinned by tag in `AGENT_BASE`.

## Quick start

```bash
cp .env.example .env          # port, image tag, password
make up                       # build and start (base + daemon fragments)
```

Open <http://127.0.0.1:4096>. The UI is published on loopback by default because
`OPENCODE_SERVER_PASSWORD` has a weak fallback — set a real password before
`OPENCODE_BIND_IP=0.0.0.0`.

```bash
make build      # image only (scripts/bake.sh)
make smoke      # UI status, s6 services, inner daemon, CLI version
make logs
make exec       # shell as the agent user (uid 1000)
make debug      # shell as root
```

`make up` and `scripts/compose.sh` assemble the stack from agent-base's compose
fragments; `docker compose up` alone starts the UI without the daemon grants.

## How it is put together

| Piece | Comes from |
|---|---|
| base image (Debian, agent user, s6 services, dockerd, toolchain) | `AGENT_BASE` build arg, default `agent-base:1.4.0` |
| OpenCode | `npm install -g opencode-ai@${OPENCODE_VERSION}` in `image/Dockerfile` |
| sandbox (devices, seccomp, proxy, limits, mounts, skills) | agent-base compose fragments via `scripts/compose.sh` |
| entrypoint, hooks, healthcheck, restart policy | agent-base |

State lives under `/home/agent`:

| Path | Volume | Holds |
|---|---|---|
| `.config/opencode` | `opencode-config` | providers and models |
| `.local/share/opencode` | `opencode-data` | `auth.json`, session database, snapshots |
| `.local/state/opencode` | `opencode-state` | XDG state |
| `workspace` | – | working directory (mount something here) |

No provider configuration is baked in. Configure providers in the UI, or seed a
config from [examples/config/opencode.jsonc](examples/config/opencode.jsonc).

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | overview and reading order |
| [docs/configuration.md](docs/configuration.md) | every variable, volume and provider option |
| [docs/troubleshooting.md](docs/troubleshooting.md) | UI unreachable, 401, unhealthy, daemon missing |
| [.agents/README.md](../../.agents/README.md) | working on this repository: map, invariants, checks |

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | the OpenCode layer on top of agent-base |
| `docker-compose.yml` | the stack: port, credentials, state volumes |
| `scripts/compose.sh` | fragment assembler wrapper (agent-base does the work) |
| `scripts/bake.sh` | builds and tags the image, deriving provenance from git |
| `scripts/smoke.sh` | runtime check of a running stack |
| `docker-bake.hcl` | bake targets, pins, OCI labels |
| `examples/` | config, env and compose starting points (not used by the build) |
| `docs/`, `.agents/` | documentation for users and for agents |

## License

MIT.
