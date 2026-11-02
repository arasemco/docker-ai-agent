# Configuration reference

## Environment

All variables are optional; every default works with no configuration.

| Variable | Default | Read by | Meaning |
|---|---|---|---|
| `AGENT_WORKSPACE` | `$HOME/workspace` | `agent-run` | working directory; must be writable |
| `AGENT_DOCKERD` | `1` | `dockerd` service | `0` keeps the daemon down (agent still runs) |
| `AGENT_DOCKERD_TIMEOUT` | `30` | `agent` service | seconds to wait for daemon readiness |
| `AGENT_DOCKERD_MAX_RESTARTS` | `3` | `dockerd` service | failed starts in a row before idling |
| `AGENT_RESTART_MAX` | `3` | `agent` service | failed starts in a row before stopping the container |
| `AGENT_HEALTHCHECK` | `auto` | healthcheck | `auto`, `docker`, `agent`, `url:<url>`, `off` |
| `AGENT_HEALTH_URL` | – | healthcheck | extra URL that must answer |
| `AGENT_USER` | `agent` | build + services | account the services run as |
| `AGENT_UID` / `AGENT_GID` | `1000` | build | uid/gid of that account |
| `XDG_RUNTIME_DIR` | `$HOME/.docker/run` | daemon | daemon socket directory |
| `DOCKER_HOST` | `unix://$XDG_RUNTIME_DIR/docker.sock` | docker clients | daemon socket |
| `AGENT_DOCKER_VOLUME` | `agent-docker` | `compose.common.yml` | volume (or host path) for daemon data |
| `AGENT_CPUS` / `AGENT_MEMORY` | `2` / `4G` | `compose.common.yml` | container limits |
| `AGENT_HOSTNAME` | `agent` | `compose.common.yml` | container hostname |
| `AGENT_SUBID_REMAP` | `1` | `cont-init.d/10-prepare` | rewrite `/etc/subuid`/`subgid` into the ids this container can reach |
| `PROXY`, `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`, `http_proxy`, `https_proxy`, `all_proxy`, `no_proxy` | – | `compose.common.yml` | see [Proxy](#proxy) |

## Launch line

What the agent service runs is decided by the image, not by the compose file and
not by an environment variable: `/etc/services.d/agent/run` names the executable
and its arguments, then calls `agent-service-start`. The base image launches
`agent-idle`; the OpenCode and dsh images launch their CLI (`opencode web …`,
`dsh web`). The claude image launches the idler because Claude Code is an
interactive TUI; run it from `make exec`. A container `CMD` is not forwarded to
the CLI: s6-overlay runs it as a one-off foreground command once the services are
up, then halts the container. Use `docker exec` to work with the running agent.

## Proxy

`compose.common.yml` resolves each proxy variable itself, first match wins:

```
HTTP_PROXY   -> http_proxy  -> PROXY -> (empty)
HTTPS_PROXY  -> https_proxy -> PROXY -> (empty)
ALL_PROXY    -> all_proxy   -> PROXY -> (empty)
http_proxy   -> HTTP_PROXY  -> PROXY -> (empty)
https_proxy  -> HTTPS_PROXY -> PROXY -> (empty)
all_proxy    -> ALL_PROXY   -> PROXY -> (empty)
```

That is the variable itself, then the other case of the same knob (tools
disagree about which one they read), then one generic `PROXY` value, then
nothing. A network with a single proxy therefore needs one `PROXY=...` line,
not eight; an explicitly set per-scheme variable wins over it.

`NO_PROXY` is not a proxy address, so it has no `PROXY` fallback: when neither
case is set it defaults to `localhost,127.0.0.1,::1`, because with a proxy
configured and `NO_PROXY` empty a request to the container's own loopback would
be sent to the proxy and fail. Each case fills the other (`NO_PROXY`/`no_proxy`).

`ALL_PROXY` is also the standard catch-all some clients read directly, but it is
not a substitute for `PROXY` here: setting only `ALL_PROXY` leaves the
scheme-specific variables empty.

## Volumes

| Source | Volume | Target |
|---|---|---|
| `compose.common.yml` | `agent-docker` | `/home/agent/.local/share/docker` |

The workspace stays inside the container: no service binds a host directory
onto it. A child stack adds its own config/state volumes in its compose file.

## Skills

Agent Skills are directories holding a `SKILL.md` (YAML frontmatter with
`name` and `description`) plus optional scripts and resources. Agent-compatible
CLIs discover them under `~/.agents/skills` and their tool-specific paths, and
load the body on demand through their `skill` tool.

The image creates `/home/agent/.agents/skills` owned by the agent user. A local
override can bind a host library there read-only, so one library serves every
agent container:

```yaml
# compose/local.yml
services:
  opencode:
    volumes:
      - ~/.agents/skills:/home/agent/.agents/skills:ro
```

Read-only is deliberate: a skill may execute its scripts, but it should not
rewrite the shared library from inside a container. Drop the `:ro` in the local
override to allow edits through the agent.

A child image can also ship skills of its own by copying them into
`/home/agent/.agents/skills`.

## Hooks

Drop `*.sh` files into `/etc/agent-entrypoint.d/` from a child image:

```dockerfile
COPY hooks/ /etc/agent-entrypoint.d/
```

A hook is sourced by `agent-run` as the agent user, after daemon readiness and
before the CLI starts. It may rewrite `$@` (`set -- web --no-open "$@"`) and
export variables the CLI reads. Keep hooks non-fatal: `set -e` is active.

## Healthcheck modes

| Mode | Passes when |
|---|---|
| `auto` | `AGENT_HEALTH_URL` answers (if set) and the s6 `agent` service is up; a dead daemon only warns |
| `docker` | `docker info` answers (strict) |
| `agent` | the s6 `agent` service is up |
| `url:<url>` | an HTTP GET succeeds |
| `off` | always |

## Exit status

The container exits when the `agent` service exits 0, or when it has failed
`AGENT_RESTART_MAX` times. The CLI's own status is recorded in
`/run/agent/exit-code`; the container's status is s6's.
