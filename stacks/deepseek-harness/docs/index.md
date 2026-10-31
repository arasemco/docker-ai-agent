# dsh documentation

This repository packages the [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
(`dsh`) Web UI as a container on top of [agent-base](../../../docs/index.md).
agent-base owns the sandbox — Debian base, agent user, s6 supervision, rootless
Docker daemon, toolchain, s6 services, hooks and healthcheck. This repository
owns dsh: Node 22, the CLI, its flag translation and its healthcheck.

## Reading order

| Document | Answers |
|---|---|
| [configuration.md](configuration.md) | variables, host networking, credentials, where state lives |
| [troubleshooting.md](troubleshooting.md) | UI unreachable, healthcheck failing, 401, daemon, credentials |

Working on the repository instead of running it? [`.agents/README.md`](../../../.agents/README.md)
has the map, invariants and checks.

## The short version

`image/Dockerfile` compiles Node 22 from the official source tarball (agent-base
ships Node 18, and dsh requires ≥22.19), installs `@deepseek-ai/dsh` from npm,
adds a hook that turns `DSH_*` variables into `dsh web` options, ships
`services.d/agent/run` with the stack's launch line (`dsh web`), and overrides
the healthcheck with one that signs a browser-session cookie and requires HTTP
200. The compose file runs it with host networking, because dsh binds loopback
only. `make up` starts it, `make smoke` proves the UI, both services and the
inner daemon.
