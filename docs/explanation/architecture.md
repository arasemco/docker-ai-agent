# Architecture

## Modules

```
versions.env ──▶ tooling/bake.sh ──▶ base image(s) + one image per stack
base/        sandbox image, contract, open/compose and bake fragments
stacks/<id>  one CLI: image, launch, state, health, compose, bake, probe, docs
compose/     common service and host overlay contract
tooling/     build, checks, smoke, generation, release
```

The base owns the runtime. A stack owns exactly one CLI and the metadata around
it. Nothing in a stack replaces the base service scripts.

## Base image

```
debian:bookworm-slim (digest-pinned)
├── Node/npm, yq, git/gh, python3, pipx+uv, build toolchain
├── docker-ce + rootless extras
├── s6-overlay (/init, /command, /etc/s6-overlay/s6-rc.d)
├── user agent (uid/gid 1000, home /home/agent)
└── /usr/local/bin/{agent-service-start,agent-run,agent-idle,agent-healthcheck}
    /usr/local/lib/agent-base/{lib.sh,selftest.sh,contract.sh}
    /etc/cont-init.d/{10-ownership,20-subid,30-workspace}
    /etc/services.d/{dockerd,agent}/{run,finish}
    /etc/agent-launch.d/agent.sh      base launch line (idler)
    /etc/agent-healthcheck.d/         per-stack fragments
    /etc/agent-state.d/               per-stack state manifests
    /etc/agent-entrypoint.d/          hooks
```

`agent-base-node22` is the same sandbox plus the official Node 22 runtime,
copied from its pinned image. dsh and Claude Code build `FROM` that variant.

## Boot sequence

1. s6 `/init` is PID 1. It does not forward a container `CMD` to the agent
   service; use `docker exec` for one-off commands.
2. Stage 2 cont-init runs as root: `10-ownership` creates state dirs and applies
   the stack manifests, `20-subid` remaps subordinate ids for a rootless host,
   `30-workspace` makes the workspace writable or aborts with a clear message.
3. `dockerd` and `agent` start. `agent` waits for the daemon readiness
   notification, writes the start stamp and drops to the agent user.
4. `agent-run` reads `/etc/agent-launch.d/agent.sh`, sets `AGENT_LAUNCH`, sources
   hooks, applies their `$@` rewrite and execs the launch line.
5. On exit, the base restart policy applies: exit 0 stops the tree, a crash after
   60 s restarts, `AGENT_RESTART_MAX` failed starts stop it, a signal is a stop.

## Launch, health, state, hooks (the contract)

| Interface | Stack ships | Base behaviour |
|---|---|---|
| launch | `/etc/agent-launch.d/agent.sh` setting `AGENT_LAUNCH=(...)` | `services.d/agent/run` is fixed; `agent-run` reads the file and execs it |
| health | `/etc/agent-healthcheck.d/NN-*.sh` (exec 0/1) | one HEALTHCHECK; dispatcher modes `auto`, `stack`, `docker`, `agent`, `url:`, `off` |
| state | `/etc/agent-state.d/<id>.paths` (`path[:mode]`, `$AGENT_HOME`) | ownership init creates and chowns each entry |
| hooks | `/etc/agent-entrypoint.d/NN-*.sh` | sourced under `set -e`; may rewrite `$@`; may abort startup by design |

The contract version is `base/CONTRACT`; every stack declares
`ARG AGENT_CONTRACT` and its test stage asserts the match.

## State

| Path | Owner | Holds |
|---|---|---|
| `/home/agent/workspace` | agent | working directory |
| `/home/agent/.local/share/docker` | subuids | rootless daemon data (named volume) |
| `/home/agent/.docker/dockerd.log` | agent | daemon log |
| `/run/agent/*` | root/agent | start stamps, restart counters, exit code |
| stack state dirs | agent | declared in `/etc/agent-state.d` |

## Healthcheck

One `HEALTHCHECK` for every image. In `auto` it checks an optional
`AGENT_HEALTH_URL`, the s6 agent service, then every stack fragment; a dead
rootless daemon is a warning. `AGENT_HEALTHCHECK=off` disables even the stack
fragments, so the documented switch is true on every image.
