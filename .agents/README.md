# Working on this repository

Orientation for a coding agent (or a human in a hurry). Read this before editing.

## What this repository is

One generic sandbox image (`base/`) and one module per agent CLI
(`stacks/<id>/`), with the deployment layer in `compose/` and the build, test and
release logic in `tooling/`. No agent CLI is in the base image.

## Map

| Path | What lives there |
|---|---|
| `base/` | sandbox image: Dockerfile, rootfs, contract, tests, compose/bake fragments |
| `stacks/<id>/` | one module: `stack.yaml`, `image/`, `compose.yml`, `bake.hcl`, `test/probe.sh`, docs |
| `compose/common.yml` | profile-less, image-less, build-less shared service |
| `docker-compose.yml` | index that includes each module's compose fragment |
| `tooling/` | build, check, smoke, generate and release entry points |
| `tests/` | unit and contract checks (hermetic), plus integration/e2e homes |
| `versions.env` | every pin, version and build reference |
| `config/knobs.env` | deployment knob registry; generates `.env.example` and the environment reference |
| `docs/` | user documentation; `docs/reference/` is generated |
| `docs/adr/` | architecture decisions |
| `examples/` | copy-paste deployment material, never consumed by the build |

## Invariants

1. **Generic core.** No host names, IPs, registry paths, personal paths or host
   binds in `base/`, `compose/common.yml` or `stacks/*/image`.
2. **No `USER` in images.** `/init` must stay PID 1 as root; services drop to the
   agent user themselves.
3. **One contract.** The launch line, health fragments, state manifests and hooks
   are defined by `base/CONTRACT.md`; a stack adds files, it does not replace the
   base run script.
4. **One source per fact.** A version belongs in `versions.env`; a knob belongs in
   `config/knobs.env`; a stack's identity belongs in its `stack.yaml`. Everything
   else is generated or checked.
5. **Discover, don't enumerate.** Use `tooling/stacks.sh`; no hand-maintained
   stack list in make, smoke, CI or docs.
6. **Explicit files, minimal machinery.** Plain bash/Docker/Compose/Bake; no
   codegen framework, no new runtime dependency in an image.
7. **Version bump on change.** `base/` change -> `BASE_VERSION`; a stack image
   change -> that stack's CLI version. `tests/contract/version-bump.sh` enforces
   it against the merge base.

## Recipes

**Add a stack.** Create `stacks/<id>/` with `stack.yaml`, `image/` (Dockerfile,
launch, optional state/health/hooks), `compose.yml`, `bake.hcl`,
`test/probe.sh`, a README and `docs/`. Add one `include:` entry to
`docker-compose.yml`. Run `make check`. Nothing else lists the stack.

**Add a base service.** `base/rootfs/etc/services.d/<name>/run` with the
`#!/command/with-contenv bash` shebang, plus `finish` if it needs restart policy.
The test stage discovers scripts with `base/tests/lint.sh`; do not edit a list.

**Change a runtime default.** Update `config/knobs.env` (and the image ENV when it
is a runtime default), then `make generate && make check`.

**Bump a pin.** Edit `versions.env`; run `make generate-check` to catch reference
drift. Base changes also bump `BASE_VERSION`.

## Checks before committing

```bash
make check
make generate-check
tooling/bake.sh test
tooling/bake.sh test-node22
make test-dsh          # only when the dsh integration fixture exists
```

`make check` is hermetic: markdown links, stack manifests, version literals,
compose config, bake `--print`, security guards and generated drift. Image test
stages add shellcheck and the base contract. `make smoke PROFILE=<id>` is the
runtime check.
