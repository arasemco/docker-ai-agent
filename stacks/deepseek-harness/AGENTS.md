# AGENTS.md

Instructions for AI coding agents working in this repository.

**Read [`.agents/README.md`](.agents/README.md) first** — repository map,
invariants and the checks to run. User documentation is in [`docs/`](docs/index.md).

Task-specific skills live in [`.agents/skills/`](.agents/skills/):
`bump-agent-base`, `configure-credentials`, `debug-healthcheck`.

## Hard rules

1. The runtime image stays on agent-base. Node is compiled from source inside an
   agent-base build stage; no other base image, no third-party apt repository.
2. `AGENT_BASE`, `NODE_VERSION` + `NODE_SHA256`, and `DSH_VERSION` are pinned and
   bumped deliberately, together in the Dockerfile and the bake file.
3. Sandbox settings belong to agent-base; select fragments with `WITH`.
4. dsh's UI is loopback-only: keep `network_mode: host`, keep wildcard `DSH_HOST`
   refused.
5. `DEEPSEEK_API_KEY` never goes into the environment; the credentials file is
   the only path.
6. No `USER 1000:1000` in the Dockerfile; `/init` must be PID 1 as root.
7. Comments and docs describe behaviour, not history.

## Verify before finishing

```bash
shellcheck scripts/*.sh image/hooks/*.sh
make build
make up && make smoke
```
