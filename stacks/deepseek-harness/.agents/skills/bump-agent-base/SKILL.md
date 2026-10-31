---
name: bump-agent-base
description: Move this stack to a newer agent-base image — update every place the base tag is pinned, rebuild, and verify the sandbox and UI still come up. Use when agent-base publishes a version, or a fix (for example the inner daemon under a rootless host) is needed from it.
metadata:
  area: upgrade
  files: image/Dockerfile, docker-compose.yml, docker-bake.hcl, .env.example
---

# Bump agent-base

## Where the pin lives

| File | Field |
|---|---|
| `image/Dockerfile` | `ARG AGENT_BASE` |
| `docker-compose.yml` | `AGENT_BASE:` build arg default |
| `docker-bake.hcl` | `variable "AGENT_BASE"` |
| `.env.example` | `AGENT_BASE=` |
| `.env` (gitignored) | `AGENT_BASE=` |
| `docs/`, `README.md` | prose mentions |

Registry-prefixed values (`registry.example/agent-base:1.4.1`) are correct when
the base is pulled; a bare `agent-base:1.4.1` resolves to a locally built image.

## Steps

1. In agent-base, read `BASE_VERSION` from `docker-bake.hcl`; make sure that tag
   is built locally or pushed.
2. Update the files above.
3. `make build` — the first build after a base change re-runs the Node stage only
   if its inputs changed; otherwise it is cached.
4. `make up && make smoke` — smoke runs dsh's real healthcheck, lists both s6
   services and reports the inner daemon.
5. Commit the bump alone, with the reason.

## Verify

```bash
grep -rn "agent-base:[0-9]" image/Dockerfile docker-compose.yml docker-bake.hcl .env.example
make build && make up && make smoke
```
