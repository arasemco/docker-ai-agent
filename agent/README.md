# Working on this repository

Orientation for a coding agent (or a human in a hurry). Read this before editing;
it explains the constraints that are not obvious from the files.

## What this repository is

A single Docker image (`image/`) that other repositories build their agent
images on top of, plus the compose fragments and scripts to run it. There is no
agent CLI in this repository, and there should never be one.

## Map

| Path | What lives there | Safe to change? |
|---|---|---|
| `image/Dockerfile` | the image: base, packages, user, s6, entrypoint wiring | yes, but check pinned digests |
| `image/rootfs/` | files copied into the image (entrypoint, services, cont-init, hooks dir) | yes |
| `compose/*.yml` | one fragment per concern, keyed `agent-base` | yes, keep them single-purpose |
| `docker-compose.yml` | default stack: `include:` of base + daemon + image | yes, keep generic |
| `scripts/compose.sh` | fragment assembler and service renamer | carefully |
| `scripts/bake.sh` | provenance derivation + `docker buildx bake` | carefully |
| `scripts/smoke.sh` | runtime validation | yes |
| `docker-bake.hcl` | targets, pinned versions, OCI labels | yes |
| `docs/` | user documentation | yes |
| `examples/` | copy-paste material, not used by the build | yes |

## Invariants

1. **Generic core.** No host names, IPs, registry paths, personal paths or
   project names outside `examples/`. Verify:
   `grep -rniE "asemo|omesa|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|/home/[a-z]+/" image compose docker-compose.yml scripts docker-bake.hcl makefile README.md`
2. **No `USER` in child images.** `/init` must stay PID 1 as root; services drop
   to the agent user with `/command/s6-setuidgid`. Ending the image with
   `USER 1000:1000` breaks the entrypoint.
3. **Fragments stay single-purpose.** A fragment may only own the keys its
   concern needs. `image.yml` builds; it does not set `command` or mounts.
   `daemon.yml` owns the daemon's devices and volume; nothing else.
4. **Every fragment declares the volume it mounts.** Otherwise including it
   fails with `refers to undefined volume`.
5. **Comments describe behaviour, not history.** No "used to", "we decided",
   "the user asked". State what the code does and why it must.
6. **Pinned inputs stay pinned.** Base digest, s6 version + sha256, CLI/engine
   versions. Never introduce `:latest` in a `FROM` or a version range.
7. **Version bump on image change.** Changing anything under `image/` requires a
   `BASE_VERSION` bump in `docker-bake.hcl`; children pin that tag.

## Recipes

**Add a package.** `image/Dockerfile`, the appropriate apt block. Keep the block
grouping (base tools, toolchain, utilities) and pin versions where a package
version matters.

**Add a service.** `image/rootfs/etc/services.d/<name>/run` with the
`#!/command/with-contenv bash` shebang, plus a `finish` script if it needs
restart policy. Add it to the `test` stage's shellcheck list in the Dockerfile.

**Add a compose feature.** New file in `compose/`, keyed `agent-base`, owning one
concern, declaring any volume it mounts. Register it in `scripts/compose.sh`'s
fragment ordering (`base daemon proxy limits mounts`) and document it in
`docs/compose.md` and the README table.

**Change a default.** Update the image `ENV`, the fragment that passes it, and
the table in `docs/configuration.md` — in the same commit.

## Checks before committing

```bash
shellcheck image/rootfs/usr/local/bin/* image/rootfs/usr/local/lib/agent-base/*.sh \
           scripts/*.sh image/rootfs/etc/cont-init.d/* \
           image/rootfs/etc/services.d/*/run image/rootfs/etc/services.d/*/finish
scripts/bake.sh test          # image builds; shellcheck + tool matrix inside
make smoke                    # real container: services, health, tools
docker compose config >/dev/null && scripts/compose.sh --with daemon,proxy,limits,mounts --file compose/image.yml -- config >/dev/null
```

`make smoke` reports the rootless daemon as `SKIP` on hosts whose Docker is
itself rootless; that is expected, not a failure. Use
`SMOKE_REQUIRE_DOCKER=1` where the daemon must work.
