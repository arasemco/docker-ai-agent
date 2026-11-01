# Configuration reference

Everything is optional except a credential. Defaults work; the stack builds and
runs without one, but `claude` will ask you to sign in.

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_IMAGE` | `claude:local` | tag for the built image |
| `CLAUDE_VERSION` | `2.1.316` | exact `@anthropic-ai/claude-code` version |
| `CLAUDE_HOME_HOST` | `claude-home` | volume or host path mounted at `CLAUDE_CONFIG_DIR` |
| `CLAUDE_CODE_OAUTH_TOKEN` | – | long-lived subscription token from `claude setup-token` |
| `ANTHROPIC_API_KEY` | – | API key for direct Anthropic API billing |
| `AGENT_BASE` | `agent-base:1.5.0` | base image the Dockerfile builds from |
| `CLAUDE_CONFIG_DIR` | `/home/agent/.claude` | set by the image; every path Claude Code writes lives here |

The sandbox variables (`AGENT_DOCKERD`, `AGENT_CPUS`, `PROXY`, …) are shared with
every stack; see [the base configuration reference](../../../docs/configuration.md).

## Authentication

Precedence is Claude Code's, not this stack's: `ANTHROPIC_API_KEY` wins, then
`CLAUDE_CODE_OAUTH_TOKEN`, then a login stored in `$CLAUDE_CONFIG_DIR`.

- **API key.** Set `ANTHROPIC_API_KEY` in `.env`. In an interactive session
  Claude Code asks once whether to use it and remembers the answer; `claude -p`
  uses it directly.
- **Subscription.** Run `claude setup-token` on a machine with a browser (it
  prints a one-year token), then set `CLAUDE_CODE_OAUTH_TOKEN` in `.env`. This
  is the headless path for CI and for containers, where `/login`'s browser
  callback cannot reach the host's browser.

`claude auth status` prints the active method and exits non-zero when nothing
usable is configured; `make smoke PROFILE=claude` runs it for you.

## Interactive use

The CLI needs a TTY, so it runs in an exec session, not as the service:

```bash
make exec PROFILE=claude            # shell as uid 1000, then: claude
docker compose --profile claude exec --user 1000 claude claude
```

The container's own stdio is not a terminal; `docker compose up` does not give
Claude Code one.

## Unattended use

`claude -p` reads a prompt, prints the result and exits, so it composes with
scripts and CI:

```bash
docker compose --profile claude exec --user 1000 claude \
    claude -p "explain this repository" --output-format text
```

The container keeps running after the command exits; the exit code is the CLI's.

## Remote Control

A subscription account can start the Remote Control server in an exec session:

```bash
docker compose --profile claude exec --user 1000 claude \
    claude remote-control --name claude
```

It is not the service's launch line because it first needs a claude.ai login and
a trusted workspace, both interactive. It also has requirements this stack
cannot satisfy with an API key: a Pro/Max/Ultra/Team/Enterprise subscription,
`api.anthropic.com` (no custom `ANTHROPIC_BASE_URL`), and no
`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`.

## State

| Path under `/home/agent/.claude` | Holds |
|---|---|
| `settings.json` | permissions, hooks, environment defaults |
| `CLAUDE.md` | global instructions, loaded every session |
| `.credentials.json` | login credentials, mode 0600 |
| `projects/`, `history.jsonl` | transcripts, prompt history, auto memory |
| `file-history/`, `plans/`, `tasks/` | checkpoints, plan files, task lists |
| `.claude.json` | app state, account details, personal MCP servers |

`CLAUDE_CONFIG_DIR` is set in the image, so `.claude.json` lives in the volume
instead of as a separate file in the home directory.

## Global instructions and skills

- Global instructions are `$CLAUDE_CONFIG_DIR/CLAUDE.md`, i.e.
  `/home/agent/.claude/CLAUDE.md` inside the container.
- Personal skills are `$CLAUDE_CONFIG_DIR/skills/<name>/SKILL.md`.
- The shared Agent Skills root is mounted read-only at `/home/agent/.agents/skills`.
  Claude Code reads its personal directory, not that path; symlink individual
  skills into `$CLAUDE_CONFIG_DIR/skills` when you want to reuse them.

## Healthcheck

The base healthcheck (`AGENT_HEALTHCHECK=auto`) proves the s6 `agent` service is
up; here that service runs the idler, so it stays healthy whether or not you
have signed in. `make smoke` adds the CLI version and `claude auth status`.
