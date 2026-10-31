# agent-base documentation

`agent-base` is a container image for AI coding-agent CLIs: a Debian sandbox
with an unprivileged user, a rootless Docker daemon under s6 supervision, and
the toolchain agents expect. It ships no agent — child images add their own CLI.

## Reading order

| Document | What it answers |
|---|---|
| [architecture.md](architecture.md) | What is inside the image? How does it boot? Who runs what? |
| [compose.md](compose.md) | How do the compose fragments fit together? How does a child stack use them? |
| [configuration.md](configuration.md) | Every environment variable, volume, path and hook. |
| [build.md](build.md) | Building, tagging, publishing, and where the OCI metadata comes from. |
| [troubleshooting.md](troubleshooting.md) | The failures worth knowing before they happen. |

Working on the repository itself (rather than using the image)?
[start here](../agent/README.md) — the map, invariants and checks a coding agent
needs.

## The one-paragraph version

`image/` builds Debian 12 with Node/npm from Debian, an `agent` user at
uid/gid 1000, docker-ce rootless, Python/uv/yq and a build toolchain. `s6-overlay`
is PID 1 and runs two longruns: `dockerd` (announces readiness when the API
answers) and `agent` (waits for that, then execs `$AGENT_CMD`). Compose is a set
of per-concern fragments in `compose/`; the root `docker-compose.yml` includes
the default three, and `scripts/compose.sh` assembles other combinations or
renames the service for a child stack. A child image only needs `FROM`,
its CLI, and `ENV AGENT_CMD`.

## Conventions used throughout

- **Fragment** — a compose file in `compose/` that owns one concern and keys the
  canonical service name `agent-base`.
- **Child image** — an image built `FROM agent-base`, adding one agent CLI.
- **Agent user** — the unprivileged account (`agent`, uid/gid 1000) that both
  services run as; the container's PID 1 stays root.
- **`AGENT_*`** — variables read by the image/entrypoint (`AGENT_CMD`,
  `AGENT_WORKSPACE`, `AGENT_DOCKERD`, …). Everything under `image/` is generic;
  values for a particular host belong in `.env` or `compose/local.yml`.
