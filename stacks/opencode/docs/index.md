# opencode documentation

This repository packages the [OpenCode](https://opencode.ai) CLI and Web UI as a
container on top of [agent-base](../../../docs/index.md). agent-base owns
the sandbox — Debian base, agent user, s6 supervision, rootless Docker daemon,
toolchain, s6 services, healthcheck — and this repository owns exactly one thing:
OpenCode.

## Reading order

| Document | Answers |
|---|---|
| [configuration.md](configuration.md) | which variables exist, where state lives, how providers are configured |
| [troubleshooting.md](troubleshooting.md) | the UI is unreachable, unhealthy, 401, config not applied, daemon missing |

Working on the repository rather than running it? [`.agents/README.md`](../../../.agents/README.md)
has the map, invariants and checks.

## The short version

`image/Dockerfile` installs `opencode-ai` from npm into the base image and
ships `services.d/agent/run` with the stack's launch line (`opencode web ...`).
The compose file carries the port, credentials and state volumes, and merges
the shared sandbox anchors; it sets no `command:`. `make up` assembles and
starts it, `make smoke` proves the UI answers and the services are up.
