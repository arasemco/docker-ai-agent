# Building and publishing

## Targets

| Command | Produces |
|---|---|
| `make build` / `scripts/bake.sh` | `agent-base:latest` and `agent-base:<BASE_VERSION>` |
| `make test` / `scripts/bake.sh test` | image + test stage (shellcheck, tool matrix); exports nothing |
| `make smoke` | builds, starts with the anchor set, validates from inside |
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

The workflow lives at [`.gitea/workflows/build.yml`](../.gitea/workflows/build.yml)
and targets this repository's Gitea instance only — there is no second forge to
satisfy, so the registry host and namespace are derived from the Gitea context
rather than configured.

On every push and pull request it:

1. resolves the registry (`<gitea host>/<owner>`) and the commit metadata;
2. builds the base image's `test` stage (shellcheck plus the tool matrix);
3. on pushes and tags: logs in, builds and pushes `agent-base`;
4. then builds and pushes `opencode` and `dsh`, which build `FROM` the tag the
   previous step just pushed.

Pull requests run the same builds without logging in and without pushing, so a
broken Dockerfile or script fails the check and nothing is published.

### Registry credentials

The workflow needs one repository secret:

| Secret | Contents |
|---|---|
| `GIT_TOKEN` | a Gitea access token with the **`write:package`** scope, created by the account that owns the registry namespace |

A job token is **not** an alternative. Gitea injects `GITEA_TOKEN` into every job
and it works for the API and for git, but the container registry rejects it:

```
Error response from daemon: Get "https://<host>/v2/": unauthorized
```

`permissions: packages: write` does not change that, and the registry
documentation itself points at a personal access token as the credential to use
in place of a password — which is also what accounts with 2FA require.

If the secret is missing the workflow fails at a dedicated check with that
instruction, before docker login would produce a generic denial. The login
username is the repository owner, the account the token belongs to — not
necessarily the user who triggered the run.

### Cache

Build layers are cached in the registry at `<REGISTRY>/agent-base:buildcache`.
The workflow reads it on every run and writes it only where push rights exist
(`CACHE_READ` / `CACHE_WRITE` in the bake file). A failed read is a cache miss,
not a failure.

The GitHub-only `type=gha` cache is not used: it needs the GitHub Actions cache
service, which a self-hosted forge does not provide.

### Image publishing

Each run pushes two tags per image: the version tag from the bake file
(`BASE_VERSION`, `OPENCODE_VERSION`, `DSH_VERSION`) and `latest`.
