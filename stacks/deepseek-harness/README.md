# deepseek-harness

The [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`)
Web UI in a container, built on [agent-base](../../README.md): an
s6-supervised sandbox with a rootless Docker daemon, a development toolchain and
persistent state.

This repository owns dsh. The sandbox — Debian base, agent user, s6 services,
toolchain, entrypoint, hooks and healthcheck — comes from agent-base, pinned by
tag in `AGENT_BASE`. Two things are dsh-specific and live here: Node 22 (the base
ships Node 18, dsh needs ≥22.19) and the healthcheck that proves an authenticated
request succeeds.

## Quick start

```bash
cp .env.example .env          # base tag, dsh version, port
make up                       # build and start (base + daemon fragments)
```

`make logs` prints the launch URL. Open it, sign in, and add the DeepSeek API key
under Settings → Models.

The first build compiles Node 22 from source and takes a while; later builds use
the cached stage until `NODE_VERSION` changes.

```bash
make build      # image only (scripts/bake.sh)
make smoke      # healthcheck, s6 services, inner daemon, dsh version
make test       # verify a real API key + a headless run (needs credentials)
make logs
make exec       # shell as the agent user (uid 1000)
make debug      # shell as root
```

## Why host networking

dsh's web server binds `127.0.0.1` and refuses wildcard addresses, because it
would expose remote code execution to the network. A container's loopback is its
own, so a published port would forward to an address where nothing listens.
`network_mode: host` makes the container's `127.0.0.1:3080` the host's, so the UI
answers at <http://localhost:3080> with the same loopback-only exposure dsh
intends. This is Linux-only; on Docker Desktop run dsh on the host instead. See
[docs/configuration.md](docs/configuration.md#host-networking).

## How it is put together

| Piece | Comes from |
|---|---|
| base image (Debian, agent user, s6 services, dockerd, toolchain) | `AGENT_BASE`, default `agent-base:1.4.1` |
| Node 22 | compiled from the official source tarball (`NODE_VERSION`, `NODE_SHA256`) |
| dsh | `npm install -g @deepseek-ai/dsh@${DSH_VERSION}` |
| flag translation (`DSH_*` → `dsh web` options) | `image/hooks/20-dsh-flags.sh`, sourced by agent-base's agent service |
| healthcheck | `image/healthcheck.mjs` (signed session cookie, expects 200) |
| sandbox settings (devices, seccomp, proxy, limits, mounts, skills) | agent-base compose fragments via `scripts/compose.sh` |

State lives in the `dsh-home` volume (`/home/agent/.dsh`): profiles, credentials
written by the UI, and session history.

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | overview and reading order |
| [docs/configuration.md](docs/configuration.md) | variables, host networking, credentials, state, healthcheck |
| [docs/troubleshooting.md](docs/troubleshooting.md) | UI unreachable, healthcheck failing, 401, daemon |
| [.agents/README.md](../../.agents/README.md) | working on this repository: map, invariants, checks |

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | dsh on agent-base: Node build stage, runtime, test stage |
| `image/healthcheck.mjs` | authenticated healthcheck |
| `image/hooks/20-dsh-flags.sh` | `DSH_*` → CLI flag translation |
| `docker-compose.yml` | host networking, credentials, `DSH_*` |
| `scripts/compose.sh` | fragment assembler wrapper (agent-base does the work) |
| `scripts/bake.sh` | builds and tags the image, deriving provenance from git |
| `scripts/smoke.sh` | runtime check of a running stack |
| `docker-bake.hcl` | bake targets, pins, OCI labels |
| `examples/` | env, compose and credentials starting points (not used by the build) |
| `docs/`, `.agents/` | documentation for users and for agents |

## License

MIT.
