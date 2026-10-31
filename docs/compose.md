# Compose model

## Fragments

`compose/` holds one file per concern; every fragment keys the canonical service
name `agent-base`, so including them all merges into a single service.

| Fragment | Owns | Knobs |
|---|---|---|
| `base.yml` | service skeleton, `AGENT_*` toggles | `AGENT_*` |
| `daemon.yml` | `/dev/fuse`, `/dev/net/tun`, seccomp exceptions, `agent-docker` volume | `AGENT_DOCKER_VOLUME` |
| `image.yml` | build of `image/` for the `base` profile | `AGENT_IMAGE` |
| `proxy.yml` | outbound proxy pass-through | `PROXY`, `HTTP_PROXY`, … |
| `limits.yml` | CPU/memory limits | `AGENT_CPUS`, `AGENT_MEMORY` |
| `mounts.yml` | workspace bind | `AGENT_WORKSPACE_HOST` |
| `skills.yml` | shared Agent Skills root, read-only | `AGENT_SKILLS_HOST` |

Every fragment declares the volumes it mounts, so the composing file never
repeats them.

## Profiles

The root `docker-compose.yml` includes all fragments and defines one service per
stack, each gated by a profile:

```bash
docker compose --profile opencode up -d      # OpenCode Web UI
docker compose --profile dsh up -d           # dsh Web UI (host networking)
docker compose --profile all up -d           # sandbox and every stack
make up PROFILE=dsh
```

`docker compose --profile opencode config` shows exactly what a profile
resolves to.

## Stack services

A stack service carries only its own concerns — build, command, ports,
credentials and state — because it extends the sandbox:

```yaml
opencode:
  extends:
    service: agent-base
  profiles: ["opencode"]
  build:
    context: ./stacks/opencode/image
  command: ["web", "--port", "4096", "--hostname", "0.0.0.0"]
```

`extends` copies the parent's merged definition, so devices, seccomp, the
daemon volume, proxy values and limits all apply without being repeated. It also
inherits the parent's profile, which is why the sandbox's `all` profile selects
every stack as well; a stack profile selects exactly one.

## Relative paths

Build contexts are relative to the repository root (`image`,
`stacks/<name>/image`) because the root compose file includes the fragments.
Inside an included fragment, a path is resolved against that fragment's own
directory — the reason `compose/image.yml` uses `../image`.

## Local overrides

`compose/local.yml` is gitignored and is the place for per-host additions
(extra binds, a second cache directory). Add it explicitly:

```bash
docker compose --profile opencode -f docker-compose.yml -f compose/local.yml up -d
```

`examples/compose/local.yml` is a starting point.
