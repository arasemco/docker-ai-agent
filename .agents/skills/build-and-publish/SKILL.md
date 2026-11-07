---
name: build-and-publish
description: Build, tag and push the images; explain where the OCI metadata comes from and what a release tag must satisfy. Use when a task builds, versions, publishes or releases an image.
metadata:
  area: build
  files: versions.env, tooling/bake.sh, tooling/provenance.sh, tooling/release.sh
---

# Build and publish

## Versions

`versions.env` is the only source. `tooling/bake.sh` sources it, derives
provenance and passes every pin as a build arg. Do not copy a version into a
Dockerfile, compose file or bake file.

## Build

```bash
tooling/bake.sh agent-base
tooling/bake.sh agent-base-node22
tooling/bake.sh opencode dsh claude
tooling/bake.sh test test-node22
tooling/bake.sh <id>-test
tooling/bake.sh --print all          # inspect tags/args without building
```

`tooling/bake.sh` discovers `base/bake.hcl` and `stacks/*/bake.hcl`; a stack
target is defined next to its image.

## Publish

`REGISTRY` is derived from the git remote by `tooling/provenance.sh`, or set
explicitly. `tooling/release.sh --push` asserts the tag equals
`v<BASE_VERSION>`, builds the base variants, then every stack, with
`--provenance=mode=max --sbom=generator`.

## Release gates

- PR: `tests/contract/version-bump.sh` against the merge base; a `base/` change
  requires a higher `BASE_VERSION`, a stack image change requires that CLI
  version bump.
- Tag: `tooling/release.sh` refuses a tag that does not match `versions.env`.
- CI: `checks.yml`, `build.yml`, `release.yml`; actions are pinned by commit.

## Provenance

OCI labels come from the commit date, author, source URL, licence and base image;
the generated pin matrix is `docs/reference/versions.md`. Run
`make generate-check` after a bump.
