# claude documentation

This repository packages [Claude Code](https://code.claude.com) as a container on
top of [agent-base](../../../docs/index.md). agent-base owns the sandbox — Debian
base, agent user, s6 supervision, rootless Docker daemon, toolchain, hooks and
healthcheck — and this repository owns exactly one thing: Claude Code.

## Reading order

| Document | Answers |
|---|---|
| [configuration.md](configuration.md) | which variables exist, where state lives, how authentication works, interactive and headless use |
| [troubleshooting.md](troubleshooting.md) | no terminal, not signed in, config not persisted, remote control unavailable, daemon missing |

Working on the repository rather than running it? [`.agents/README.md`](../../../.agents/README.md)
has the map, invariants and checks.

## The short version

`image/Dockerfile` copies Node 22 from its official image (Claude Code declares
`engines >=22`, and agent-base ships Node 18), installs
`@anthropic-ai/claude-code` from npm, and sets
`CLAUDE_CONFIG_DIR=/home/agent/.claude` so settings, credentials, transcripts
and `.claude.json` share one volume. Claude Code is an interactive TUI with no
local server mode, so `image/services.d/agent/run` keeps the base idler
running and the CLI is started through `make exec`. `make smoke` proves the
binary runs and reports the authentication state.
