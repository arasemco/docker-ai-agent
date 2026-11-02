---
name: compose-stacks
description: Change the shared common service in compose.common.yml (sandbox, environment, daemon volume) and the per-stack services in docker-compose.yml that extend it. Use when a task changes how a stack is put together, adds a shared concern, or adds a new stack.
metadata:
  area: compose
  files: compose.common.yml, docker-compose.yml, makefile, scripts/smoke.sh
---

# Compose stacks

## Model

`docker-compose.yml` has one service per stack, behind a profile. The shared
sandbox, environment and daemon volume are the `common` service in
`compose.common.yml`; every stack extends it:

```yaml
opencode:
  profiles: ["opencode"]
  extends: {file: ./compose.common.yml, service: common}
  build: { context: ./stacks/opencode/image, target: opencode }
  environment:
    OPENCODE_SERVER_PASSWORD: "${OPENCODE_SERVER_PASSWORD:-changeme123}"
```

`compose.common.yml` is not part of the project: it is only a source for
`extends.file`, so it is never started. It must stay profile-less and
image-less; otherwise `--profile base` selects every stack and stack builds
inherit the base target.

| Common service owns | Knobs |
|---|---|
| `init`/tty/restart, seccomp exceptions, devices, resource limits | `AGENT_HOSTNAME`, `AGENT_CPUS`, `AGENT_MEMORY` |
| `AGENT_*` toggles and proxy resolution (`HTTP_PROXY` → `http_proxy` → `PROXY`) | `AGENT_DOCKERD*`, `AGENT_RESTART_MAX`, `PROXY`, `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY` |
| the inner daemon's data volume | `AGENT_DOCKER_VOLUME` |

A stack service carries only its own build, environment, ports and volumes; it
inherits the common environment and daemon volume. It has no `command:` and no
launch line: what the CLI runs belongs to the image's s6 service
(`stacks/<name>/image/services.d/agent/run`). A container `CMD` is a one-off
foreground command run by s6-overlay, not the agent's launch line.

## Adding a shared concern

1. Put it in `compose.common.yml`'s `common` service if every stack needs it.
2. If it mounts a named volume, declare that volume in `docker-compose.yml`;
   `extends` copies service config, not the top-level `volumes:` block.
3. Document the knob in `docs/compose.md` and `docs/configuration.md`.

## Adding a stack

1. Add a service to `docker-compose.yml` with `profiles: ["<name>"]` and
   `extends: {file: ./compose.common.yml, service: common}`.
2. Add its build, ports, environment and state volumes; do not repeat the
   common environment or the daemon volume.
3. Add a target in `docker-bake.hcl` and `PROFILE` support in
   `makefile`/`scripts/smoke.sh`.

## Combining

```bash
docker compose --profile opencode up -d     # OpenCode Web UI
docker compose --profile dsh up -d          # dsh Web UI (host networking)
docker compose --profile base up -d         # sandbox only, no agent CLI
make up PROFILE=dsh
```

A gitignored `compose/local.yml` holds per-host additions; pass it explicitly
with `-f`. `examples/compose/local.yml` is a starting point.

## Rules that are easy to break

- **Common stays generic.** No profile, image, build, command or deployment
  default in `compose.common.yml`.
- **No deployment values in the core.** A shared setting may read an environment
  variable, but must not default to a host, IP or personal path.
- **Volumes.** The daemon volume is inherited; a stack adds only its own state
  volumes. Declare every named volume in `docker-compose.yml`.
- **Relative paths.** Build contexts are relative to `docker-compose.yml`:
  `./image` for the base, `./stacks/<name>/image` for a stack.
- **No commands.** A launch line in compose hides what s6 runs and duplicates
  the image; keep it in `services.d/agent/run`.

## Verify

```bash
docker compose config >/dev/null
for p in base opencode dsh claude; do docker compose --profile "$p" config >/dev/null; done
make config PROFILE=opencode
scripts/smoke.sh opencode                   # running stack
```

## References

- [docs/compose.md](../../../docs/compose.md)
- [docs/configuration.md](../../../docs/configuration.md)
