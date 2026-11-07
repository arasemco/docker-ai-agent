# opencode

The [OpenCode](https://opencode.ai) CLI and Web UI in a container, built on
[agent-base](../../README.md): an s6-supervised sandbox with a rootless
Docker daemon, a development toolchain and persistent state.

This repository owns only OpenCode. The sandbox — Debian base, the `agent` user,
the s6 services, the toolchain, hooks and the healthcheck —
comes from agent-base, pinned by tag in `AGENT_BASE`.

## Quick start

```bash
cp .env.example .env          # port, image tag, password
make up                       # build and start the stack
```

Open <http://127.0.0.1:4096>. The UI is published on loopback by default because
`OPENCODE_SERVER_PASSWORD` has a weak fallback — set a real password before
`OPENCODE_BIND_IP=0.0.0.0`.

```bash
make build      # image only (tooling/bake.sh)
make smoke      # UI status, s6 services, inner daemon, CLI version
make logs
make exec       # shell as the agent user (uid 1000)
make debug      # shell as root
```

`make up` builds and starts the stack; the sandbox devices, seccomp options,
limits and mounts come from the shared `common` service the stack extends.

## How it is put together

| Piece | Comes from |
|---|---|
| base image (Debian, agent user, s6 services, dockerd, toolchain) | `AGENT_BASE` build arg, pinned in `versions.env` |
| OpenCode | `npm install -g opencode-ai@${OPENCODE_VERSION}` in `base/Dockerfile` |
| launch line (`opencode web ...`) | `image/agent-launch.d/agent.sh` |
| sandbox (devices, seccomp, proxy, limits, mounts, skills) | the shared `common` service in `compose/common.yml` |
| s6 services, hooks, healthcheck, restart policy | agent-base |

State lives under `/home/agent`:

| Path | Volume | Holds |
|---|---|---|
| `.config/opencode` | `opencode-config` | providers and models |
| `.local/share/opencode` | `opencode-data` | `auth.json`, session database, snapshots |
| `.local/state/opencode` | `opencode-state` | XDG state |
| `workspace` | – | working directory (mount something here) |

No provider configuration is baked in. Configure providers in the UI; a JSONC
file you keep yourself can also be placed at
`/home/agent/.config/opencode/opencode.jsonc`.

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | overview and reading order |
| [docs/reference/configuration.md](../../docs/reference/configuration.md) | every variable, volume and provider option |
| [docs/how-to/troubleshooting.md](../../docs/how-to/troubleshooting.md) | UI unreachable, 401, unhealthy, daemon missing |
| [.agents/README.md](../../.agents/README.md) | working on this repository: map, invariants, checks |

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | the OpenCode layer on top of agent-base |
| `image/agent-launch.d/agent.sh` | the launch line the s6 agent service uses |
| `image/state.d/opencode.paths` | state directories created at boot |
| `image/health.d/50-opencode.sh` | per-stack healthcheck fragment |
| `compose.yml` | the module service: port, credentials, state and workspace volumes |
| `bake.hcl` | the module build and test targets |
| `test/probe.sh` | runtime probe used by `tooling/smoke.sh` |
| `docs/` | module documentation |

## License

MIT.
