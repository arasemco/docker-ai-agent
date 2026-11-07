# Verification commands

Run from the repository root.

| Check | Command | Expected |
|---|---|---|
| Hermetic contract suite | `make check` | `check OK` |
| Generated reference and `.env.example` | `make generate-check` | `generate --check OK` |
| Base test stage | `tooling/bake.sh test` | exit 0; lint + contract + selftest |
| Node 22 base test stage | `tooling/bake.sh test-node22` | exit 0 |
| Stack test stages | `tooling/bake.sh opencode-test claude-test dsh-test` | exit 0 |
| dsh integration | `make test-dsh` | needs the credentials fixture |
| Compose config | `for p in base opencode dsh claude; do docker compose --profile "$p" config >/dev/null; done` | exit 0 |
| Bake syntax | `tooling/bake.sh --print all >/dev/null` | exit 0 |
| Runtime | `make smoke PROFILE=<id>` | `OK (<id>)`; a daemon `SKIP` is expected on rootless hosts |
| Runtime, daemon mandatory | `SMOKE_REQUIRE_DOCKER=1 make smoke PROFILE=<id>` | fails if the inner daemon is down |
| Security guards | `tests/contract/security.sh` | `security OK` |

## Interpreting failures

- `newuidmap: ... Operation not permitted` — the container's `/etc/subuid`
  names ids the parent namespace cannot reach. `cont-init.d/20-subid` rewrites
  them automatically; if it still fails, check for a `rewrote /etc/subuid ...`
  line and that `AGENT_SUBID_REMAP` is not `0`.
- `service "..." refers to undefined volume ...` — a module fragment mounts a
  volume it does not declare. Each stack declares its own top-level `volumes:`;
  `extends` does not import them.
- `target stage "..." could not be found` — the bake target and the stack
  Dockerfile disagree. Each stack's `bake.hcl` names its own stage.
- `contract: MISSING ...` — the stack image did not copy the contract file into
  `/etc/agent-*`; check its Dockerfile against `base/CONTRACT.md`.
