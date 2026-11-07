# Building, versions and release

## Versions

`versions.env` is the only file that carries a pin. `tooling/versions.sh` loads
it and derives the image references; `tooling/bake.sh` exports the values to
buildx. Dockerfiles and compose take required values; they have no fallback
copies.

| Kind | Example |
|---|---|
| base version | `BASE_VERSION` |
| base inputs | `DEBIAN_REF`, `S6_OVERLAY_VERSION` + sha256, `DOCKER_VERSION`, `UV_VERSION` |
| Node runtime | `NODE_REF` |
| stack CLIs | `OPENCODE_VERSION`, `DSH_VERSION`, `CLAUDE_VERSION`, `PNPM_VERSION` |

## Targets

```bash
tooling/bake.sh agent-base
tooling/bake.sh agent-base-node22
tooling/bake.sh test test-node22
tooling/bake.sh opencode dsh claude
tooling/bake.sh opencode-test claude-test dsh-test
```

`tooling/bake.sh` discovers `base/bake.hcl` and `stacks/*/bake.hcl`, so a new
stack adds a target without editing a central list. Image tags are `:latest` and
the declared version; the Node 22 base variant is `:<base>-node22`.

## Build and run

```bash
make build PROFILE=opencode   # base + one stack
make build-all                # base variants + every stack
make up PROFILE=dsh           # build, then compose up --no-build
```

Compose has no `build:` keys; `tooling/bake.sh` is the only build entry point.

## Gates

- `make check` — hermetic checks (links, manifests, versions, compose, bake,
  security, generated drift).
- `make generate-check` — reference pages and `.env.example` are current.
- image test stages — shellcheck, the base contract, and each stack's contract
  assertion and `--version`.
- `tests/contract/version-bump.sh` — a `base/` change requires a higher
  `BASE_VERSION`; a stack image change requires that CLI version bump.
- `tooling/release.sh` — the tag must equal `v<BASE_VERSION>`; it builds base
  variants, then stacks, and pushes with provenance/SBOM when `--push` is set.

## CI

- `.gitea/workflows/checks.yml` runs `make check`, the generated check and the PR
  version-bump gate.
- `.gitea/workflows/build.yml` runs the tests, then pushes the base variants and
  every stack on `main`/tags; pull requests build without pushing.
- `.gitea/workflows/release.yml` runs the release gate on `v*.*.*`.

The registry prefix is derived from the git remote by `tooling/provenance.sh`, or
set explicitly with `REGISTRY=`; OCI labels use the commit date, author, source,
licence and base image.
