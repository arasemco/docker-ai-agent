---
name: build-and-publish
description: Build, tag and push the agent-base image, and explain where its OCI metadata comes from — scripts/bake.sh derives commit, author, remote, licence and version before invoking bake. Use when a task builds, versions or publishes the image.
metadata:
  area: release
  files: docker-bake.hcl, scripts/bake.sh
---

# Build and publish

## Build

```bash
scripts/bake.sh                 # default group: agent-base:latest + :<BASE_VERSION>
scripts/bake.sh --print         # resolved config as JSON, no build
scripts/bake.sh test            # image + test stage, exports nothing
scripts/bake.sh agent-base-dev  # mutable :dev tag
make build / make test          # same, through the makefile
```

The build context is `image/` only. `docker-bake.hcl` sets
`context = "image"`, so compose files, docs and scripts never enter the image.

## Provenance

`docker-bake.hcl` cannot read git, so `scripts/bake.sh` fills the variables:

| Variable | Derived from |
|---|---|
| `GIT_SHA`, `GIT_REF` | `git rev-parse`; the exact tag when HEAD is tagged |
| `AUTHOR` | author of the last commit |
| `SOURCE_URL` | git remote, normalised to https (any remote name; `BAKE_REMOTE` pins one) |
| `REGISTRY` | that remote's host + owner: `ghcr.io/<owner>`, `registry.gitlab.com/<owner>`, or `<host>/<owner>` |
| `VENDOR` | author's mail domain |
| `LICENSES` | SPDX id detected in `LICENSE` / `COPYING` |
| `BASE_VERSION` | exact `vX.Y.Z` tag at HEAD |

Rules:

- an environment variable always wins over a derived value;
- `BAKE_DERIVE=0` disables derivation (leaves bake's neutral defaults);
- `BAKE_QUIET=1` silences the per-value summary;
- outside a git checkout nothing is derived, and bake uses its defaults;
- `--push` without a registry is refused before building — an unprefixed tag
  would target Docker Hub's `library/` namespace. `BAKE_ALLOW_DOCKERHUB_PUSH=1`
  is the explicit opt-in.

## Publish

```bash
docker login registry.example          # the host of ${REGISTRY}
scripts/bake.sh --push                 # tags + push, derived from the remote
REGISTRY=registry.example/team scripts/bake.sh --push   # explicit override
```

Tags produced: `<REGISTRY>/agent-base:latest` and `:<BASE_VERSION>`.

## Versioning

`BASE_VERSION` is the image's own version, independent of any CLI layered on
top. Bump it whenever anything under `image/` changes, then update the
`AGENT_BASE` pin in child images. Tags are immutable in practice: never reuse a
`BASE_VERSION` for different contents.

## Pinned inputs

| Input | Where | Bump |
|---|---|---|
| Debian base | `DEBIAN_BASE` (bake) + `DEBIAN_REF` (Dockerfile) | `docker buildx imagetools inspect debian:bookworm-slim`, update both |
| s6-overlay | `S6_OVERLAY_VERSION` + three sha256 in `image/Dockerfile` | new release tag, replace digests |
| Docker Engine | `DOCKER_VERSION` | `apt-cache madison docker-ce` |
| uv | `UV_VERSION` | PyPI release |

## References

- [docs/build.md](../../../docs/build.md)
- [.agents/checks.md](../../checks.md)
