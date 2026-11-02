# claude

The [Claude Code](https://code.claude.com) CLI in a container, built on
[agent-base](../../README.md): an s6-supervised sandbox with a rootless Docker
daemon, a development toolchain and persistent state.

This repository owns only Claude Code. The sandbox — Debian base, the `agent`
user, the s6 services, the toolchain, hooks and the healthcheck — comes from
agent-base, pinned by tag in `AGENT_BASE`.

Claude Code is an interactive terminal UI with no local web server, so the
container keeps the sandbox up and the CLI runs on demand:

```bash
cp .env.example .env          # image tag, Anthropic credentials
make up PROFILE=claude        # build and start the sandbox
make exec PROFILE=claude      # shell as the agent user
claude                        # inside that shell
```

`make up` starts only the sandbox; the `claude` process is started by you, not by
the agent service. Unattended runs use `claude -p`, and a Claude subscription can
start `claude remote-control` in an exec session.

## Authentication

One of these, exported in `.env`:

| Variable | Use it for |
|---|---|
| `ANTHROPIC_API_KEY` | direct API billing |
| `CLAUDE_CODE_OAUTH_TOKEN` | a Claude subscription; generate it with `claude setup-token` on a machine with a browser |

`make smoke PROFILE=claude` prints `claude auth status`, so a container with no
usable credential is visible immediately.

## How it is put together

| Piece | Comes from |
|---|---|
| base image (Debian, agent user, s6 services, dockerd, toolchain) | `AGENT_BASE` build arg, default `agent-base:1.5.0` |
| Node 22 | copied from the official Node image, pinned by digest (base ships Node 18) |
| Claude Code | `npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION}` in `image/Dockerfile` |
| launch line (idler) | `image/services.d/agent/run` |
| sandbox (devices, seccomp, proxy, limits, mounts, skills) | the shared `common` service in `compose.common.yml` |
| s6 services, hooks, healthcheck, restart policy | agent-base |

State lives under `/home/agent/.claude` (`CLAUDE_CONFIG_DIR`), a named volume:

| Path | Holds |
|---|---|
| `settings.json`, `CLAUDE.md` | personal settings and global instructions |
| `.credentials.json` | login credentials |
| `projects/`, `history.jsonl`, `file-history/` | transcripts, prompt history, checkpoints |
| `.claude.json` | app state, account details, personal MCP servers |

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | overview and reading order |
| [docs/configuration.md](docs/configuration.md) | variables, state, authentication, headless and remote-control use |
| [docs/troubleshooting.md](docs/troubleshooting.md) | no terminal, not signed in, config not persisted, daemon missing |
| [.agents/README.md](../../.agents/README.md) | working on this repository: map, invariants, checks |

## Layout

| Path | Purpose |
|---|---|
| `image/Dockerfile` | the Claude Code layer on top of agent-base |
| `image/services.d/agent/run` | the s6 agent service's launch line (the idler) |
| `docker-compose.yml` | the stack: credentials and state volume |
| `scripts/bake.sh` | builds and tags the image, deriving provenance from git |
| `scripts/smoke.sh` | runtime check of a running stack |
| `docker-bake.hcl` | bake targets, pins, OCI labels |
| `docs/`, `.agents/` | documentation for users and for agents |

## License

MIT.
