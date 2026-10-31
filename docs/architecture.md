# Architecture

## Image

```
debian:bookworm-slim (digest-pinned)
├── Node/npm, yq, git/gh, python3, pipx+uv, build toolchain   (apt + PyPI)
├── docker-ce + rootless extras (dockerd, rootlesskit, fuse-overlayfs)
├── s6-overlay 3.2.3.0 (/init, /command, /etc/s6-rc)
├── user "agent" (uid/gid 1000, home /home/agent)
└── /usr/local/bin/{agent-entrypoint,agent-run,agent-healthcheck}
    /usr/local/lib/agent-base/selftest.sh
    /etc/cont-init.d/10-prepare
    /etc/services.d/{dockerd,agent}/{run,finish}
    /etc/agent-entrypoint.d/            (hooks, empty in the base image)
```

Glbc is a requirement, not a preference: agent CLIs ship prebuilt native
modules and static binaries that do not load on musl. Node comes from Debian
(18.20 on bookworm); a CLI that requires a newer Node installs its own.

## Boot sequence

1. **ENTRYPOINT** `agent-entrypoint` runs as root. It writes the container's
   `CMD` (NUL-separated) to `/run/agent/args` and execs `/init`. s6 does not
   forward `CMD` to services, so this hand-off is how `docker run image --help`
   reaches the CLI.
2. **s6 stage 1** copies the container environment into `/run/s6/container_environment`
   so services can see it through `#!/command/with-contenv`.
3. **s6 stage 2 — cont-init**: `10-prepare` runs as root, creates state
   directories, takes ownership of a root-owned mount point if needed, and
   aborts with a clear message if the workspace is still unwritable.
4. **s6 stage 2 — services**: `dockerd` and `agent` start. `agent` waits up to
   `AGENT_DOCKERD_TIMEOUT` for `dockerd`'s readiness notification.
5. On container stop, s6 terminates both services and runs their `finish`
   scripts.

## Services

| Service | User | Supervision |
|---|---|---|
| `dockerd` | `agent` | restarts on exit; after `AGENT_DOCKERD_MAX_RESTARTS` failed starts it idles instead of looping; readiness is announced on s6's notification fd once `docker info` answers |
| `agent` | `agent` | waits (bounded) for `dockerd` readiness, then execs `$AGENT_CMD`; exit 0 stops the container, a crash after 60 s is restarted, `AGENT_RESTART_MAX` failed starts in a row stop the container, a signal never restarts |

Both services run through `/command/s6-setuidgid agent`, so neither the CLI nor
the daemon ever runs as root. The container itself is root at PID 1, which is
why `docker exec` lands as root; use `--user 1000` for the agent's shell.

## State

| Path | Owner | Holds |
|---|---|---|
| `/home/agent/workspace` | `agent` | working directory (`AGENT_WORKSPACE`) |
| `/home/agent/.local/share/docker` | subuids | rootless daemon data root (named volume) |
| `/home/agent/.docker/dockerd.log` | `agent` | daemon log |
| `/run/agent/args` | root | container `CMD`, NUL-separated |
| `/run/agent/exit-code` | root | last CLI exit status |
| `/run/agent/*.fails` | root | restart counters |

## Hooks

`/etc/agent-entrypoint.d/*.sh` are **sourced** by `agent-run` as the agent user,
after the daemon is ready and before the CLI starts. Sourcing (not executing)
lets a hook rewrite `$@`, e.g. turning environment variables into CLI flags.
Hooks must not fail the start.

## Healthcheck

`agent-healthcheck` runs as root and checks, in `auto` mode: `AGENT_HEALTH_URL`
if set, then that the `AGENT_CMD` process exists. A dead rootless daemon is
reported as a warning, because the agent works without it. `AGENT_HEALTHCHECK`
selects `auto`, `docker`, `agent`, `url:<url>` or `off`.
