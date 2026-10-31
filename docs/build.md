# Building and publishing

## Targets

| Command | Produces |
|---|---|
| `make build` / `scripts/bake.sh` | `agent-base:latest` and `agent-base:<BASE_VERSION>` |
| `make test` / `scripts/bake.sh test` | image + test stage (shellcheck, tool matrix); exports nothing |
| `make smoke` | builds, starts with the fragment set, validates from inside |
| `scripts/bake.sh agent-base-dev` | mutable `:dev` tag |

The image context is `image/` only (`docker-bake.hcl` sets `context = "image"`);
compose files, docs, examples and scripts are host tooling.

## Pinned inputs

| What | Where | How to bump |
|---|---|---|
| Debian base | `docker-bake.hcl` `DEBIAN_BASE`, `image/Dockerfile` `DEBIAN_REF` | `docker buildx imagetools inspect debian:bookworm-slim`, update both |
| s6-overlay | `S6_OVERLAY_VERSION` + three per-arch sha256 in `image/Dockerfile` | new release tag, replace the digests |
| Docker Engine | `DOCKER_VERSION` | `apt-cache madison docker-ce` inside the image |
| uv | `UV_VERSION` | PyPI release |
| Node/npm, yq, git… | Debian packages | follow the base image |

## Provenance

`scripts/bake.sh` fills the bake variables the HCL cannot compute:

| Variable | Derived from |
|---|---|
| `GIT_SHA`, `GIT_REF` | `git rev-parse`, exact tag if HEAD is tagged |
| `AUTHOR` | author of the last commit |
| `SOURCE_URL` | the git remote (any name; `BAKE_REMOTE` pins one) |
| `REGISTRY` | that remote's host + owner, forge-aware (`ghcr.io/<owner>` on GitHub, `registry.gitlab.com/<owner>` on GitLab, `<host>/<owner>` otherwise) |
| `VENDOR` | author's mail domain |
| `LICENSES` | SPDX id detected in `LICENSE` / `COPYING` |
| `BASE_VERSION` | exact `vX.Y.Z` tag at HEAD |

An environment variable always wins. `BAKE_DERIVE=0` disables derivation,
`BAKE_QUIET=1` silences the summary. `--push` without a registry fails before
building, because an unprefixed tag would target Docker Hub's `library/`.

```bash
docker login registry.example
scripts/bake.sh --push
```

## Versioning

`BASE_VERSION` is the image's own version, independent of any CLI on top. Bump
it whenever the image contents change (paths, defaults, services), and pin the
new tag in child images.

## CI

`.github/workflows/docker-build-push.yml` runs the test target on every push and
pull request, then builds and pushes on pushes and tags. Registry and source URL
are derived from the workflow context (GitHub or Gitea Actions); the bake file
itself carries no identity.
