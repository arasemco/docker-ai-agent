---
name: bump-agent-base
description: Move this stack to a newer agent-base image — update every place the base tag is pinned, rebuild, and verify the sandbox still comes up. Use when agent-base publishes a new version or a fix is needed from it.
metadata:
  area: upgrade
  files: image/Dockerfile, docker-compose.yml, docker-bake.hcl, .env.example
---

# Bump agent-base

## Where the pin lives

The base tag appears in six places and they must agree:

| File | Field |
|---|---|
| `image/Dockerfile` | `ARG AGENT_BASE` |
| `docker-compose.yml` | `AGENT_BASE:` build arg default |
| `docker-bake.hcl` | `variable "AGENT_BASE"` |
| `.env.example` | `AGENT_BASE=` |
| `.env` (gitignored) | `AGENT_BASE=` |
| `README.md`, `docs/` | prose mentions, if any |

A registry-prefixed value (`registry.example/agent-base:1.4.0`) is correct when
the base is pulled; a bare `agent-base:1.4.0` resolves to a locally built image.

## Steps

1. Confirm the target base exists: in agent-base, `BASE_VERSION` in
   `docker-bake.hcl` is the version, and the image is either built locally
   (`docker images | grep agent-base`) or pushed.
2. Update the six places above.
3. `make build` — the build fails fast if the base cannot be pulled.
4. `make up && make smoke` — the smoke test reports the UI status, both s6
   services, the inner daemon and the opencode version.
5. Commit the pin bump on its own, with the reason (for example: "agent-base
   1.4.0 adapts /etc/subuid so the inner daemon works under a rootless host
   daemon").

## What breaks if you skip a place

- `image/Dockerfile` only: compose builds the same image, so it looks fine, but
  `docker build` without compose uses a different base.
- `docker-bake.hcl` only: `scripts/bake.sh` produces an image on the old base
  while compose produces one on the new base.
- `.env` only: works on this machine, new machines fall back to the default.

## Verify

```bash
grep -rn "agent-base:[0-9]" image/Dockerfile docker-compose.yml docker-bake.hcl .env.example
make build && make up && make smoke
```
