---
name: compose-anchors
description: Add or change the shared compose anchors in docker-compose.yml (sandbox, environment, volumes) and the per-stack services that merge them. Use when a task changes how a stack is put together, adds a shared concern, or adds a new stack.
metadata:
  area: compose
  files: docker-compose.yml, makefile, scripts/smoke.sh
---

# Compose anchors

## Model

There is one `docker-compose.yml`. Shared settings are YAML anchors grouped by
concern; each service merges the mapping anchors and lists the volume anchors it
needs (YAML merges mappings, not lists).

| Anchor | Owns | Knobs |
|---|---|---|
| `x-sandbox` | `init`/tty/restart, seccomp exceptions, devices, resource limits | `AGENT_HOSTNAME`, `AGENT_CPUS`, `AGENT_MEMORY` |
| `x-agent-env` | `AGENT_*` toggles and proxy resolution (`HTTP_PROXY` → `http_proxy` → `PROXY`) | `AGENT_DOCKERD*`, `AGENT_RESTART_MAX`, `PROXY`, `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY` |
| `x-docker` | the inner daemon's data volume | `AGENT_DOCKER_VOLUME` |
| `x-skills` | the shared Agent Skills root, read-only | `AGENT_SKILLS_HOST` |

A service carries build, environment, ports and volumes only. It has no
`command:` and no launch line: what the CLI runs belongs to the image's s6
service (`stacks/<name>/image/services.d/agent/run`). A container `CMD` is a
one-off foreground command run by s6-overlay, not the agent's launch line.

## Adding an anchor

1. Define `x-<concern>: &<concern>` at the top level, with a header comment that
   says what the single concern is and why the settings exist.
2. If it mounts a volume, declare that volume in the top-level `volumes:` block;
   otherwise the service fails with `refers to undefined volume`.
3. Merge it into the services that need it (`<<: *<concern>` for mappings; add
   the alias to the service's `volumes:` list for volumes).
4. Document it in the anchor table in `docs/compose.md`, and any variables it
   reads in `docs/configuration.md`.

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

- **One concern per anchor.** Do not fold ports, build args or launch settings
  into a shared anchor; a stack service adds its own.
- **No deployment values in the core.** An anchor may read an environment
  variable, but must not default to a host, IP or personal path.
- **Mapping vs list.** `<<:` merges mappings only; volumes must be listed
  explicitly per service.
- **Relative paths.** Build contexts are relative to the compose file:
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
