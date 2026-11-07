# dsh

The [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`)
Web UI in a container, built on [agent-base](../../README.md): an
s6-supervised sandbox with a rootless Docker daemon, a development toolchain and
persistent state.

This repository owns dsh. The sandbox — Debian base, agent user, s6 services,
toolchain, s6 services, hooks and healthcheck — comes from agent-base, pinned by
tag in `AGENT_BASE`. Two things are dsh-specific and live here: Node 22 (the base
ships Node 18, dsh needs ≥22.19) and the healthcheck that proves an authenticated
request succeeds.

## Quick start

```bash
cp .env.example .env          # base tag, dsh version, port
make up                       # build and start the stack
```

`make logs` prints the launch URL. Open it, sign in, and add the DeepSeek API key
under Settings → Models.

The Node 22 runtime comes from the pinned agent-base-node22 variant; later builds
reuse the cached base layers.

```bash
make build      # image only (tooling/bake.sh)
make smoke      # healthcheck, s6 services, inner daemon, dsh version
make test-dsh   # verify a real API key + a headless run (needs credentials)
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
[docs/reference/configuration.md](../../docs/reference/configuration.md#host-networking).

## How it is put together

| Piece | Comes from |
|---|---|
| base image (Debian, agent user, s6 services, dockerd, toolchain) | `AGENT_BASE` build arg, pinned in `versions.env` |
| Node 22 | `agent-base-node22` variant, pinned by `NODE_REF` |
| dsh | `npm install -g @deepseek-ai/dsh@${DSH_VERSION}` |
| launch line (`dsh web`) | `image/agent-launch.d/agent.sh` |
| flag translation (`DSH_*` → `dsh web` options) | `image/hooks/20-dsh-flags.sh`, sourced by agent-run |
| healthcheck | `image/healthcheck.mjs` (signed session cookie, expects 200) |
| sandbox settings (devices, seccomp, proxy, limits, mounts, skills) | the shared `common` service in `compose/common.yml` |

State lives in the `dsh-home` volume (`/home/agent/.dsh`): profiles, credentials
written by the UI, and session history.

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | overview and reading order |
| [docs/reference/configuration.md](../../docs/reference/configuration.md) | variables, host networking, credentials, state, healthcheck |
| [docs/how-to/troubleshooting.md](../../docs/how-to/troubleshooting.md) | UI unreachable, healthcheck failing, 401, daemon |
| [.agents/README.md](../../.agents/README.md) | working on this repository: map, invariants, checks |

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | dsh on the Node 22 base variant: runtime and test stages |
| `image/healthcheck.mjs` | authenticated healthcheck fragment |
| `image/hooks/20-dsh-flags.sh` | `DSH_*` → CLI flag translation |
| `image/agent-launch.d/agent.sh` | the launch line the s6 agent service uses |
| `image/state.d/dsh.paths` | state directories created at boot |
| `compose.yml` | host networking, credentials, home and workspace volumes |
| `bake.hcl` | the module build and test targets |
| `test/probe.sh` | runtime probe used by `tooling/smoke.sh` |
| `docs/` | module documentation |

## License

MIT.
