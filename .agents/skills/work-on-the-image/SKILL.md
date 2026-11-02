---
name: work-on-the-image
description: Change the agent-base image itself — packages, the agent user, s6 services, the agent launch line, environment defaults — and land it with the required version bump and checks. Use when a task touches image/ or changes a runtime default.
metadata:
  area: image
  files: image/Dockerfile, image/rootfs/
---

# Work on the image

## Ground rules

- The image is **generic**: no host names, IPs, registry paths, personal
  directories or project names. Those belong in `examples/` or a consumer's
  `.env` / `compose/local.yml`.
- **Package managers only**: apt for system packages, PyPI/`pipx` for Python,
  npm for Node CLIs. No `curl | sh` installers, no unpacked release tarballs.
- **Everything pinned**: base image by digest, s6-overlay by version + per-arch
  sha256, Docker Engine / uv / CLIs by exact version.
- **No `USER` directive at the end.** `/init` must stay PID 1 as root; services
  drop to the agent user with `/command/s6-setuidgid`.
- **Bump `BASE_VERSION`** in `docker-bake.hcl` for any change under `image/`.
  Child images pin that tag; reusing it silently breaks them.

## Where things live

| Concern | File |
|---|---|
| base digest, package blocks, uv, docker-ce, ENV, WORKDIR | `image/Dockerfile` |
| service launcher, CLI runner, healthcheck, selftest | `image/rootfs/usr/local/bin/`, `image/rootfs/usr/local/lib/agent-base/` |
| stage-2 preparation (ownership, directories) | `image/rootfs/etc/cont-init.d/10-prepare` |
| longruns (`dockerd`, `agent`) | `image/rootfs/etc/services.d/*/{run,finish}` |
| hooks directory | `image/rootfs/etc/agent-entrypoint.d/` |

## Recipes

**System package.** Add it to the matching apt block: base tooling, build
toolchain, or CLI utilities. Keep the grouping — the layers are ordered so a
package change does not invalidate the toolchain layer.

**Service.** `image/rootfs/etc/services.d/<name>/run`, shebang
`#!/command/with-contenv bash`, plus `finish` when it needs restart policy.
Add both to the `test` stage's shellcheck list in `image/Dockerfile`.

**Runtime default.** Set it in the image `ENV`, pass it from
`compose.common.yml` when every stack needs it (or the stack service that owns
it), and update `docs/configuration.md` in the same commit.

**Node version.** Debian bookworm provides 18.20. Do not add a second Node to
the base; a CLI that needs newer installs its own in the child image.

## Verify

```bash
shellcheck image/rootfs/usr/local/bin/* image/rootfs/usr/local/lib/agent-base/*.sh
scripts/bake.sh test     # builds; shellcheck + tool matrix inside the image
make smoke               # both services, health, tool matrix in a real container
```

`SMOKE_REQUIRE_DOCKER=1 make smoke` also fails when the inner daemon does not
come up; it starts even inside a rootless host daemon, so a failure there is a
real regression, not an environment quirk.

## References

- [docs/architecture.md](../../../docs/architecture.md)
- [docs/configuration.md](../../../docs/configuration.md)
- [.agents/checks.md](../../checks.md)
