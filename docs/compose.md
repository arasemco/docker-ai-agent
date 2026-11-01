# Compose model

## One file, anchored sections

There is a single `docker-compose.yml`. The shared parts are defined once as
YAML anchors, grouped by concern, and each service merges the ones it needs:

| Anchor | Concern | Knobs |
|---|---|---|
| `x-sandbox` | `init`/tty/restart, seccomp exceptions, `/dev/fuse` + `/dev/net/tun`, resource limits | `AGENT_HOSTNAME`, `AGENT_CPUS`, `AGENT_MEMORY` |
| `x-agent-env` | `AGENT_*` toggles and proxy resolution, merged into each service's `environment` | `AGENT_DOCKERD*`, `AGENT_RESTART_MAX`, `PROXY`/`HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY` |
| `x-docker` | the inner daemon's data volume | `AGENT_DOCKER_VOLUME` |
| `x-skills` | the shared Agent Skills root, read-only | `AGENT_SKILLS_HOST` |

One file avoids `extends:`: reaching a differently named service with `extends`
also inherits the parent's profile and build target, which makes `--profile base`
start every stack and breaks stack builds with
`target stage "agent-base" could not be found`.

YAML merges mappings, not lists, so a service merges the mapping anchor and
lists the volume anchors it needs:

```yaml
opencode:
  profiles: ["opencode"]
  <<: *sandbox
  environment:
    <<: *agent-env
    OPENCODE_SERVER_PASSWORD: "${OPENCODE_SERVER_PASSWORD:-changeme123}"
  volumes:
    - *docker-volume
    - *skills-volume
    - ${OPENCODE_CONFIG_HOST:-opencode-config}:/home/agent/.config/opencode
```

## No commands in the compose file

A service carries build, environment, ports and volumes; it does not carry a
`command:`. Each stack image defines its own launch line in its s6 agent
service (`stacks/<name>/image/services.d/agent/run`), so `docker compose
--profile <name> up` starts exactly what the image says it starts. A runtime
`command:` is not the launch line either: s6-overlay runs the container `CMD` as
a separate foreground command after the services start. The image is the only
place the agent's launch line lives. The `base` profile and the interactive
`claude` stack keep the sandbox up because their agent service launches
`agent-idle`.

## Profiles

Each service has its own profile, so exactly one stack starts:

```bash
docker compose --profile opencode up -d      # OpenCode Web UI
docker compose --profile dsh up -d           # dsh Web UI (host networking)
docker compose --profile claude up -d        # Claude Code (interactive, via exec)
docker compose --profile base up -d          # sandbox only, no agent CLI
make up PROFILE=dsh
docker compose --profile opencode config     # what a profile resolves to
```

## Relative paths

Build contexts are relative to this file's directory, so `image` and
`stacks/<name>/image` mean exactly what they say.

## Local overrides

`compose/local.yml` is gitignored and holds per-host additions (extra binds, a
second cache directory). Pass it explicitly:

```bash
docker compose --profile opencode -f docker-compose.yml -f compose/local.yml up -d
```

`examples/compose/local.yml` is a starting point.
