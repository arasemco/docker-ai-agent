# Architecture

## Image

```
debian:bookworm-slim (digest-pinned)
├── Node/npm, yq, git/gh, python3, pipx+uv, build toolchain   (apt + PyPI)
├── docker-ce + rootless extras (dockerd, rootlesskit, fuse-overlayfs)
├── s6-overlay 3.2.3.0 (/init, /command, /etc/s6-rc)
├── user "agent" (uid/gid 1000, home /home/agent)
└── /usr/local/bin/{agent-service-start,agent-run,agent-idle,
                    agent-healthcheck}
    /usr/local/lib/agent-base/selftest.sh
    /etc/cont-init.d/10-prepare
    /etc/services.d/{dockerd,agent}/{run,finish}
    /etc/agent-entrypoint.d/            (hooks, empty in the base image)
```

Glbc is a requirement, not a preference: agent CLIs ship prebuilt native
modules and static binaries that do not load on musl. Node comes from Debian
(18.20 on bookworm); a CLI that requires a newer Node installs its own.

## Boot sequence

1. **s6 `/init`** is the image's ENTRYPOINT and PID 1. It does not forward the
   container `CMD` to the agent service: s6-overlay runs a CMD as a one-off
   foreground command after the services are up, then halts the container
   (`docker run image sh` is the useful form). The agent service's launch line
   is fixed by the image (see Launch line).
2. **s6 stage 1** copies the container environment into `/run/s6/container_environment`
   so services can see it through `#!/command/with-contenv`.
3. **s6 stage 2 — cont-init**: `10-prepare` runs as root, creates state
   directories, takes ownership of a root-owned mount point if needed, and
   aborts with a clear message if the workspace is still unwritable. It also
   rewrites `/etc/subuid` and `/etc/subgid` when the container cannot reach the
   configured subordinate ids — the case when it runs under another rootless
   daemon — so the inner `dockerd` can build its namespace.
4. **s6 stage 2 — services**: `dockerd` and `agent` start. `agent` waits up to
   `AGENT_DOCKERD_TIMEOUT` for `dockerd`'s readiness notification.
5. On container stop, s6 terminates both services and runs their `finish`
   scripts.

## Services

| Service | User | Supervision |
|---|---|---|
| `dockerd` | `agent` | restarts on exit; after `AGENT_DOCKERD_MAX_RESTARTS` failed starts it idles instead of looping; readiness is announced on s6's notification fd once `docker info` answers. Runs `dockerd-rootless.sh` (Debian) with the daemon's own flags, or `dockerd-entrypoint.sh` (Alpine) with a leading command word, whichever exists |
| `agent` | `agent` | waits (bounded) for `dockerd` readiness, then runs the launch line named by its run script (executable and arguments) as the agent user; exit 0 stops the container, a crash after 60 s is restarted, `AGENT_RESTART_MAX` failed starts in a row stop the container, a signal never restarts |

Both services run through `/command/s6-setuidgid agent`, so neither the CLI nor
the daemon ever runs as root. The container itself is root at PID 1, which is
why `docker exec` lands as root; use `--user 1000` for the agent's shell.

### Launch line

What the CLI runs is decided in exactly one place: `/etc/services.d/agent/run`
in the image. The script names the executable and its arguments, then calls
`agent-service-start`, which waits for `dockerd`, records the start time, drops
to the agent user and hands the line to `agent-run`; `agent-run` sources the
hooks and execs it. There is no environment variable selecting the CLI and no
compose `command:`.

The base image has no CLI, so its run script launches `agent-idle` and keeps the
sandbox up. A child image replaces the run script with its own line — `opencode
web --port …` in `stacks/opencode`, `dsh web` in `stacks/deepseek-harness` — and
that is what s6 supervises. The claude image keeps the idler because Claude Code
is an interactive TUI with no local server mode; its CLI runs from `make exec`.
To work with the running agent, use `docker exec`; a container `CMD` is a
separate foreground command run by s6-overlay after services start, not an
argument to the CLI.

## State

| Path | Owner | Holds |
|---|---|---|
| `/home/agent/workspace` | `agent` | working directory (`AGENT_WORKSPACE`) |
| `/home/agent/.local/share/docker` | subuids | rootless daemon data root (named volume) |
| `/home/agent/.docker/dockerd.log` | `agent` | daemon log |
| `/run/agent/exit-code` | root | last CLI exit status |
| `/run/agent/*.fails` | root | restart counters |

## Hooks

`/etc/agent-entrypoint.d/*.sh` are **sourced** by `agent-run` as the agent user,
after the daemon is ready and before the CLI starts. The executable is already
split off, so a hook rewrites the CLI's arguments (`$@`), e.g. turning
environment variables into flags. Hooks must not fail the start.

## Healthcheck

`agent-healthcheck` runs as root and checks, in `auto` mode: `AGENT_HEALTH_URL`
if set, then that the s6 `agent` service is up. A dead rootless daemon is
reported as a warning, because the agent works without it. `AGENT_HEALTHCHECK`
selects `auto`, `docker`, `agent`, `url:<url>` or `off`.
