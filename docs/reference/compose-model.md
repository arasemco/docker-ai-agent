# Compose model

Compose is the deployment layer only. Images are built by `tooling/bake.sh` and
referred to by tag; no service carries a `build:` key.

## Index and module fragments

`docker-compose.yml` is an index:

```yaml
name: agent
include:
  - path: base/compose.yml
  - path: stacks/opencode/compose.yml
  - path: stacks/dsh/compose.yml
  - path: stacks/claude/compose.yml
```

Each module owns one fragment. A stack fragment extends the shared service:

```yaml
services:
  opencode:
    profiles: ["opencode"]
    extends: {file: ../../compose/common.yml, service: common}
    image: ${OPENCODE_IMAGE:?...}
    ports: [...]
    volumes: [...]
```

`compose/common.yml` is profile-less, image-less and build-less. It owns the
sandbox devices, seccomp exceptions, default resource limits, proxy resolution
and the daemon/uv/GPG/SSH home volume references. It contains no host values.

The shared `agent-docker`, `agent-gnupg`, `agent-ssh`, `agent-workspace`,
`uv-cache` and `uv-data` volumes are declared in `base/compose.yml`, which is
always included; `extends` does not import top-level resources.

## Profiles

```bash
docker compose --profile opencode config
docker compose --profile opencode -f docker-compose.yml -f docker-compose.local.yml up -d
```

`make up PROFILE=<id>` exports the image references, builds, then runs. The
profile and service ids match for stacks; `base` maps to service `agent-base`.

## Host overlay

`docker-compose.local.yml` at the repository root is gitignored and is the only
place for host binds, the agent tree, GPU devices and host-specific limits.
`examples/compose/local.yml` is the placeholder starting point. `make` accepts
`LOCAL_COMPOSE=docker-compose.local.yml`.
