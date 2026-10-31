# Compose model

## One file, anchored sections

There is a single `docker-compose.yml`. The shared parts are defined once as
YAML anchors, grouped by concern, and each service merges the ones it needs:

| Anchor | Concern | Knobs |
|---|---|---|
| `x-sandbox` | `init`/tty/restart, seccomp exceptions, `/dev/fuse` + `/dev/net/tun`, resource limits | `AGENT_HOSTNAME`, `AGENT_CPUS`, `AGENT_MEMORY` |
| `x-agent-env` | `AGENT_*` toggles and proxy pass-through, merged into each service's `environment` | `AGENT_DOCKERD*`, `AGENT_RESTART_MAX`, `PROXY`/`HTTP_PROXY`/… |
| `x-docker` | the inner daemon's data volume | `AGENT_DOCKER_VOLUME` |
| `x-skills` | the shared Agent Skills root, read-only | `AGENT_SKILLS_HOST` |

Anchors replaced an earlier per-file fragment layout: fragments needed `include:`
plus `extends:` to reach a differently named service, and `extends` also leaks
the parent's profile and build target, which made `--profile base` start every
stack and failed stack builds with `target stage "agent-base" could not be found`.

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

## Profiles

Each service has its own profile, so exactly one stack starts:

```bash
docker compose --profile opencode up -d      # OpenCode Web UI
docker compose --profile dsh up -d           # dsh Web UI (host networking)
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
