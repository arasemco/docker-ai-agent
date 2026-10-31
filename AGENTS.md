# AGENTS.md

Instructions for AI coding agents working in this repository.

**Read [`.agents/README.md`](.agents/README.md) first** — repository map,
invariants and the checks to run. User documentation is in [`docs/`](docs/index.md).

Task-specific skills live in [`.agents/skills/`](.agents/skills/):
`bump-agent-base`, `configure-providers`, `debug-web-ui`.

## Hard rules

1. This repository adds only OpenCode. Sandbox settings (devices, seccomp,
   proxy, limits, mounts, skills) belong to agent-base and are selected as
   compose fragments.
2. `AGENT_BASE` is pinned to a version tag and bumped deliberately.
3. No `USER 1000:1000` in the Dockerfile; `/init` must be PID 1 as root.
4. State directories are created in the image owned by uid 1000.
5. No provider configuration is baked in; ship templates under `examples/`.
6. Comments and docs describe behaviour, not history.

## Verify before finishing

```bash
shellcheck scripts/*.sh
make build
make up && make smoke
```
