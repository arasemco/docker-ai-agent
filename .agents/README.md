# Working on this repository

Orientation for a coding agent (or a human in a hurry). Read this before editing;
it explains the constraints that are not obvious from the files.

Skills for specific jobs live in [`skills/`](skills/): an agent-compatible CLI
loads the matching `SKILL.md` on demand instead of keeping all of it in context.

| Skill | Use it when |
|---|---|
| [`work-on-the-image`](skills/work-on-the-image/SKILL.md) | changing `image/`, packages, services or a runtime default |
| [`compose-anchors`](skills/compose-anchors/SKILL.md) | adding or combining compose anchors |
| [`build-and-publish`](skills/build-and-publish/SKILL.md) | building, versioning or pushing the image |
| [`run-and-debug`](skills/run-and-debug/SKILL.md) | a stack starts but does not behave |
| [`child-image`](skills/child-image/SKILL.md) | building another agent image on top of agent-base |

## What this repository is

A single Docker image (`image/`) that other repositories build their agent
images on top of, plus the compose anchors and scripts to run it. There is no
agent CLI in this repository, and there should never be one.

## Map

| Path | What lives there | Safe to change? |
|---|---|---|
| `image/Dockerfile` | the image: base, packages, user, s6, service wiring | yes, but check pinned digests |
| `image/rootfs/` | files copied into the image (service launcher, services, cont-init, hooks dir) | yes |
| `docker-compose.yml` | anchored sandbox/env/volume sections + one service per stack | yes |
| `stacks/<name>/image/` | one agent CLI layer per stack (Dockerfile + files) | yes |
| `stacks/<name>/docs/`, `examples/` | stack-specific documentation and starting points | yes |

| `scripts/bake.sh` | provenance derivation + `docker buildx bake` | carefully |
| `scripts/smoke.sh` | runtime validation | yes |
| `docker-bake.hcl` | targets, pinned versions, OCI labels | yes |
| `docs/` | user documentation | yes |
| `examples/` | copy-paste material, not used by the build | yes |

## Invariants

1. **Generic core.** No host names, IPs, registry paths, personal paths or
   project names outside `examples/`. Verify:
   `grep -rniE "asemo|omesa|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|/home/[a-z]+/" image docker-compose.yml scripts docker-bake.hcl makefile README.md`
2. **No `USER` in child images.** `/init` must stay PID 1 as root; services drop
   to the agent user with `/command/s6-setuidgid`. Ending the image with
   `USER 1000:1000` breaks the s6 supervision tree.
3. **Anchors stay single-purpose.** An anchor may only own the keys its
   concern needs: `x-sandbox` holds devices, seccomp and limits;
   `x-agent-env` holds the environment; `x-docker` and `x-skills` hold their
   own volumes. A service adds its own build, ports and credentials.
4. **Every anchor declares the volume it mounts.** Otherwise including it
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

**Add a compose feature.** A new `x-<name>` anchor in `docker-compose.yml` that
owns one concern, merged into the services that need it, with its knob
documented in `docs/compose.md` and the README table.

**Add a stack.** `stacks/<name>/image/` with its Dockerfile, a service in
`docker-compose.yml` with `extends: {service: agent-base}` and
`profiles: ["<name>"]`, a target in `docker-bake.hcl`, and `PROFILE` support in
`makefile`/`scripts/smoke.sh`.

**Change a default.** Update the image `ENV`, the anchor that passes it, and
the table in `docs/configuration.md` — in the same commit.

## Checks before committing

```bash
shellcheck image/rootfs/usr/local/bin/* image/rootfs/usr/local/lib/agent-base/*.sh \
           scripts/*.sh image/rootfs/etc/cont-init.d/* \
           image/rootfs/etc/services.d/*/run image/rootfs/etc/services.d/*/finish
scripts/bake.sh test          # image builds; shellcheck + tool matrix inside
make smoke                    # real container: services, health, tools
for p in base opencode dsh claude; do docker compose --profile "$p" config >/dev/null; done
```

`make smoke` waits for the inner daemon and proves storage with an offline
build; `SMOKE_REQUIRE_DOCKER=1 make smoke` makes a missing daemon a failure. The
daemon works nested (a container inside a rootless daemon) because
`cont-init.d/10-prepare` rewrites the subordinate id ranges when the container
cannot reach the defaults.
