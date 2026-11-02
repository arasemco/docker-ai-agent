# Compose model

## One project, a shared common service

`docker-compose.yml` holds one service per stack. The shared sandbox,
environment and daemon volume live in `compose.common.yml` as the `common`
service, and every stack extends it:

```yaml
opencode:
  profiles: ["opencode"]
  extends: {file: ./compose.common.yml, service: common}
  build: { context: ./stacks/opencode/image, target: opencode }
  environment:
    OPENCODE_SERVER_PASSWORD: "${OPENCODE_SERVER_PASSWORD:-changeme123}"
```

`compose.common.yml` is not part of the project: it is only a source for
`extends.file`, so it is never started.

| Common service owns | Knobs |
|---|---|
| `init`/tty/restart, seccomp exceptions, `/dev/fuse` + `/dev/net/tun`, resource limits | `AGENT_HOSTNAME`, `AGENT_CPUS`, `AGENT_MEMORY` |
| `AGENT_*` toggles and proxy resolution, merged into each stack's `environment` | `AGENT_DOCKERD*`, `AGENT_RESTART_MAX`, `PROXY`/`HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY` |
| the inner daemon's data volume | `AGENT_DOCKER_VOLUME` |

The common service is separate because a same-file parent also passes on its
`profiles` and build target: `--profile base` would select every stack, and
stack builds would inherit the base image's target. A profile-less,
image-less `common` service cannot leak either.

`extends` merges mappings and appends sequences, so a stack inherits the
environment and the daemon volume (keyed by target) and adds only its own
build, ports, credentials and state volumes. The named volume is declared once
in `docker-compose.yml`, because `extends` copies service config, not the
top-level `volumes:` block.

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

Build contexts are relative to `docker-compose.yml`: `./image` for the base,
`./stacks/<name>/image` for a stack.

## Local overrides

`compose/local.yml` is gitignored and holds per-host additions (extra binds, a
second cache directory). Pass it explicitly:

```bash
docker compose --profile opencode -f docker-compose.yml -f compose/local.yml up -d
```

`examples/compose/local.yml` is a starting point.
