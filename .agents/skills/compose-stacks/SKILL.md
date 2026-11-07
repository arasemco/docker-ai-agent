---
name: compose-stacks
description: Change the shared common service, a stack's compose fragment, the root include index, or the host overlay. Use when adding a stack, adding a shared sandbox concern, or changing how compose fragments are assembled.
metadata:
  area: compose
  files: compose/common.yml, docker-compose.yml, stacks/*/compose.yml, makefile
---

# Compose stacks

## Model

`docker-compose.yml` is an index: `name: agent` plus one `include:` entry per
module. `base/compose.yml` and `stacks/<id>/compose.yml` hold the services.
Every fragment extends `compose/common.yml`:

```yaml
services:
  <id>:
    profiles: ["<id>"]
    extends: {file: ../../compose/common.yml, service: common}
    image: ${<ID>_IMAGE:?run through make or tooling/versions.sh --export}
```

`compose/common.yml` is profile-less, image-less and build-less. It owns the
sandbox devices, seccomp exceptions, default limits, proxy resolution and the
daemon/uv volume references. It contains no host values.

The shared `agent-docker`, `agent-workspace`, `uv-cache` and `uv-data` volumes are
declared in `base/compose.yml`; `extends` does not import top-level resources. A
stack declares its own top-level `volumes:` in its fragment.

## Images

Compose carries no `build:` keys. `tooling/bake.sh` builds; `make up` exports
the image references and runs `docker compose up --no-build`.

## Add a stack

1. Create `stacks/<id>/` with `stack.yaml`, `image/`, `compose.yml`, `bake.hcl`,
   `test/probe.sh`, docs.
2. Add one include entry to `docker-compose.yml`.
3. Run `make check`; `tooling/stacks.sh --check` validates the module.

Nothing else lists the stack; make, smoke, CI and docs use
`tooling/stacks.sh`.

## Host overlay

The deployment's host values live in gitignored `docker-compose.local.yml`:

```bash
make up PROFILE=<id> LOCAL_COMPOSE=docker-compose.local.yml
```

`examples/compose/local.yml` is the placeholder starting point. Never put host
binds, devices or limits in `compose/common.yml`.

## Verify

```bash
make check
for p in $(tooling/stacks.sh --profiles); do docker compose --profile "$p" config >/dev/null; done
tooling/bake.sh --print all >/dev/null
```
