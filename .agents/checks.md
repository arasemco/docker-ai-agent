# Verification commands

Run from the repository root.

| Check | Command | Expected |
|---|---|---|
| Shell scripts | `shellcheck -s bash -e SC1008 image/rootfs/etc/services.d/*/run image/rootfs/etc/services.d/*/finish image/rootfs/etc/cont-init.d/*` | exit 0 |
| Shell scripts (plain) | `shellcheck image/rootfs/usr/local/bin/* scripts/*.sh image/rootfs/usr/local/lib/agent-base/*.sh` | exit 0 |
| Bake file syntax | `scripts/bake.sh --print >/dev/null` | exit 0, JSON printed |
| Provenance | `scripts/bake.sh --print \| grep image.source` | derived URL, or `unknown` without a remote |
| Compose: default | `docker compose config >/dev/null` | exit 0 |
| Compose: profiles | `for p in base opencode dsh claude; do docker compose --profile "$p" config >/dev/null; done` | exit 0 |
| Build all images | `make build-all` | agent-base, opencode, dsh and claude tagged |
| Image build + unit checks | `scripts/bake.sh test` | `PASSED` |
| Runtime | `make smoke` | `OK — agent-base built, running, and healthy` |
| Runtime, daemon mandatory | `SMOKE_REQUIRE_DOCKER=1 make smoke` | same, with `daemon ... responds`, `storage driver fuse-overlayfs`, `docker build (FROM scratch) works` |
| Tool matrix only | `docker compose exec agent-base /usr/local/lib/agent-base/selftest.sh --no-docker` | `PASSED` |
| Generic core | `grep -rniE "asemo\|omesa\|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" image compose docker-compose.yml scripts docker-bake.hcl makefile README.md` | no output |

## Interpreting failures

- `newuidmap: ... Operation not permitted` — the container's `/etc/subuid`
  names ids the parent namespace cannot reach. `cont-init.d/10-prepare` rewrites
  them automatically; if it still fails, check that the rewrite logged a
  `rewrote /etc/subuid ...` line and that `AGENT_SUBID_REMAP` is not `0`.
- `service "..." refers to undefined volume ...` — a service mounts a volume the
  project does not declare; declare it in the top-level `volumes:` block.
- `target stage "agent-base" could not be found` — a stack build inherited the
  base image's build target; each stack names its own stage and sets `target:`.
