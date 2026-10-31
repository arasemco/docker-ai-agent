# Verification commands

Run from the repository root.

| Check | Command | Expected |
|---|---|---|
| Shell scripts | `shellcheck -s bash -e SC1008 image/rootfs/etc/services.d/*/run image/rootfs/etc/services.d/*/finish image/rootfs/etc/cont-init.d/*` | exit 0 |
| Shell scripts (plain) | `shellcheck image/rootfs/usr/local/bin/* scripts/*.sh image/rootfs/usr/local/lib/agent-base/*.sh` | exit 0 |
| Bake file syntax | `scripts/bake.sh --print >/dev/null` | exit 0, JSON printed |
| Provenance | `scripts/bake.sh --print \| grep image.source` | derived URL, or `unknown` without a remote |
| Compose: default | `docker compose config >/dev/null` | exit 0 |
| Compose: fragments | `scripts/compose.sh --with daemon,proxy,limits,mounts --file compose/image.yml -- config >/dev/null` | exit 0 |
| Compose: service rename | `scripts/compose.sh --service probe --file compose/image.yml -- config \| grep 'probe:'` | service renamed |
| Image build + unit checks | `scripts/bake.sh test` | `PASSED` |
| Runtime | `make smoke` | `OK — agent-base built, running, and healthy` |
| Tool matrix only | `docker compose exec agent-base /usr/local/lib/agent-base/selftest.sh --no-docker` | `PASSED` |
| Generic core | `grep -rniE "asemo\|omesa\|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" image compose docker-compose.yml scripts docker-bake.hcl makefile README.md` | no output |

## Interpreting failures

- `newuidmap: ... Operation not permitted` during `make smoke` — the host's
  Docker is rootless; the nested daemon cannot start. Expected there; the agent
  and its tools still pass.
- `service "agent-base" refers to undefined volume ...` — a fragment mounts a
  volume that is not declared. Declare it in the fragment that mounts it.
- `unable to prepare context: path ".../compose/image" not found` — a relative
  build context was resolved against the wrong directory; `compose/image.yml`
  must use `../image`, child stacks `./image`, and the assembler must anchor
  `--project-directory` to the stack file.
