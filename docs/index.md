# agent-base documentation

`agent-base` is a container image for AI coding-agent CLIs: a Debian sandbox
with an unprivileged user, a rootless Docker daemon under s6 supervision, and
the toolchain agents expect. It ships no agent — child images add their own CLI.

## Reading order

| Document | What it answers |
|---|---|
| [architecture.md](architecture.md) | What is inside the image? How does it boot? Who runs what? |
| [compose.md](compose.md) | How do the anchors, profiles and stack services fit together? |
| [configuration.md](configuration.md) | Every environment variable, volume, path and hook. |
| [build.md](build.md) | Building, tagging, publishing, and where the OCI metadata comes from. |
| [troubleshooting.md](troubleshooting.md) | The failures worth knowing before they happen. |

Working on the repository itself (rather than using an image)?
[start here](../.agents/README.md) — the map, invariants and checks a coding agent
needs.

Each stack has its own documentation next to its image:

| Stack | Documentation |
|---|---|
| OpenCode | [stacks/opencode/docs/index.md](../stacks/opencode/docs/index.md) |
| DeepSeek Harness | [stacks/deepseek-harness/docs/index.md](../stacks/deepseek-harness/docs/index.md) |

## The one-paragraph version

`image/` builds Debian 12 with Node/npm from Debian, an `agent` user at
uid/gid 1000, docker-ce rootless, Python/uv/yq and a build toolchain. `s6-overlay`
is PID 1 and runs two longruns: `dockerd` (announces readiness when the API
answers) and `agent` (waits for that, then execs `$AGENT_CMD`). `docker-compose.yml`
defines the shared sandbox as YAML anchors and one service per stack, behind a
profile; `docker compose --profile <name> up` starts exactly one stack. A stack
image only needs `FROM`, its CLI, and `ENV AGENT_CMD`.

## Conventions used throughout

- **Anchor** — a YAML anchor in `docker-compose.yml` (`x-sandbox`,
  `x-agent-env`, `x-docker`, `x-skills`) that owns one concern and is merged into
  every service that needs it.
- **Child image** — an image built `FROM agent-base`, adding one agent CLI.
- **Agent user** — the unprivileged account (`agent`, uid/gid 1000) that both
  services run as; the container's PID 1 stays root.
- **`AGENT_*`** — variables read by the image/entrypoint (`AGENT_CMD`,
  `AGENT_WORKSPACE`, `AGENT_DOCKERD`, …). Everything under `image/` is generic;
  values for a particular host belong in `.env` or `compose/local.yml`.
