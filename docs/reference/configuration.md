# Configuration reference

The generated table for every deployment variable is
[reference/environment.md](environment.md), produced from
`config/knobs.env`. `.env.example` is generated from the same file; copy it to
`.env` (gitignored) and override what you need.

Versions and image references are **not** deployment variables: they live in
`versions.env` and reach the build through `tooling/versions.sh`.

## Sandbox knobs

`AGENT_DOCKERD`, `AGENT_DOCKERD_TIMEOUT`, `AGENT_DOCKERD_MAX_RESTARTS`,
`AGENT_RESTART_MAX`, `AGENT_DOCKER_VOLUME`, `AGENT_UV_CACHE_VOLUME`,
`AGENT_UV_DATA_VOLUME`, `AGENT_WORKSPACE_HOST`, `AGENT_CPUS`, `AGENT_MEMORY`,
`AGENT_HEALTHCHECK`, `AGENT_HEALTH_URL`, `AGENT_SUBID_REMAP`, proxy variables.

## Identity

The unprivileged account is fixed: `agent`, uid/gid 1000, home `/home/agent`.
Host binds and named volumes rely on it. It is not a deployment knob.

## Launch line

The stack image ships `/etc/agent-launch.d/agent.sh`; the base
`services.d/agent/run` is fixed. There is no compose `command:`; a container
`CMD` is a separate s6 foreground command, not the launch line.

## Healthcheck

One dispatcher, modes `auto`, `stack`, `docker`, `agent`, `url:<url>`, `off`.
Stack fragments live in `/etc/agent-healthcheck.d/*.sh`; `off` disables them too.
A dead inner daemon is a warning because the agent still works without it.

## State

Each stack ships `/etc/agent-state.d/<id>.paths`, one `path[:mode]` per line;
`$AGENT_HOME` expands to the account home. The ownership init creates and chowns
those paths, so stack Dockerfiles do not need literal uid numbers.

## Hooks

`/etc/agent-entrypoint.d/NN-*.sh` are sourced by `agent-run` as the agent user,
after the launch file. They may rewrite `$@` and may abort startup by design.

## Volumes

The inner daemon uses the shared `agent-docker` volume, and the uv cache/data use
`uv-cache`/`uv-data` (all declared in `base/compose.yml`). Each stack declares its
own home and workspace volumes in its `compose.yml`; the `*_HOST` variable points
at a host path to bind instead.
