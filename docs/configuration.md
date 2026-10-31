# Configuration reference

## Environment

All variables are optional; every default works with no configuration.

| Variable | Default | Read by | Meaning |
|---|---|---|---|
| `AGENT_CMD` | `bash` | `agent` service | command the service execs |
| `AGENT_WORKSPACE` | `$HOME/workspace` | entrypoint, `agent-run` | working directory; must be writable |
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
| `AGENT_DOCKER_VOLUME` | `agent-docker` | `daemon.yml` | volume (or host path) for daemon data |
| `AGENT_WORKSPACE_HOST` | `${PWD}/workspace` | `mounts.yml` | host directory bound as the workspace |
| `AGENT_CPUS` / `AGENT_MEMORY` | `2` / `4G` | `limits.yml` | container limits |
| `AGENT_SKILLS_HOST` | `${PWD}/skills` | `skills.yml` | host directory mounted as the shared skills root |
| `AGENT_HOSTNAME` | `agent` | `base.yml` | container hostname |
| `AGENT_SUBID_REMAP` | `1` | `cont-init.d/10-prepare` | rewrite `/etc/subuid`/`subgid` into the ids this container can reach |
| `PROXY`, `HTTP_PROXY`, … | – | `proxy.yml` | see below |

## Proxy resolution

`proxy.yml` resolves each variable independently, first match wins:

```
HTTP_PROXY  →  http_proxy  →  PROXY  →  (empty)
HTTPS_PROXY →  https_proxy →  PROXY  →  (empty)
ALL_PROXY   →  all_proxy   →  PROXY  →  (empty)
```

`NO_PROXY` has no `PROXY` fallback; when neither case is set it defaults to
`localhost,127.0.0.1,::1` so local endpoints are never sent to the proxy.

## Volumes

| Fragment | Volume | Target |
|---|---|---|
| `daemon.yml` | `agent-docker` | `/home/agent/.local/share/docker` |
| `image.yml` | – | (no mount: the workspace stays inside the container) |
| `mounts.yml` | host path | `/home/agent/workspace` |

A child stack adds its own volumes (config/state) in its compose file.

## Skills

Agent Skills are directories holding a `SKILL.md` (YAML frontmatter with
`name` and `description`) plus optional scripts and resources. Agent-compatible
CLIs discover them under `~/.agents/skills` and their tool-specific paths, and
load the body on demand through their `skill` tool.

The image creates `/home/agent/.agents/skills` owned by the agent user. The
`skills` fragment mounts a host directory there read-only, so one library serves
every agent container:

```bash
AGENT_SKILLS_HOST=~/skills scripts/compose.sh --with daemon,skills -- up -d
```

Read-only is deliberate: a skill may execute its scripts, but it should not
rewrite the shared library from inside a container. Drop the `:ro` in
`compose/skills.yml` to allow edits through the agent.

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
| `auto` | `AGENT_HEALTH_URL` answers (if set) and `AGENT_CMD` is running; a dead daemon only warns |
| `docker` | `docker info` answers (strict) |
| `agent` | the `AGENT_CMD` process exists |
| `url:<url>` | an HTTP GET succeeds |
| `off` | always |

## Exit status

The container exits when the `agent` service exits 0, or when it has failed
`AGENT_RESTART_MAX` times. The CLI's own status is recorded in
`/run/agent/exit-code`; the container's status is s6's.
