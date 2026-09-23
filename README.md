# docker-dsh

[![Build and push Docker images](https://github.com/arasemco/docker-dsh/actions/workflows/docker-build-push.yml/badge.svg)](https://github.com/arasemco/docker-dsh/actions/workflows/docker-build-push.yml)
[![GHCR: dsh](https://img.shields.io/badge/ghcr.io-dsh-blue?logo=docker)](https://github.com/arasemco/docker-dsh/pkgs/container/dsh)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)
[![Debian base](https://img.shields.io/badge/base-debian%20bookworm--slim-A81D33?logo=debian)](https://www.debian.org)

A container image for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
(`dsh`), built from source. **Upstream ships no Docker support** — no
Dockerfile, `docker-compose.yml`, or `docker-bake.hcl` exist anywhere in that
repo as of this writing — so this builds it the same way the upstream README
tells a human to: `pnpm install && pnpm run build && pnpm dsh web`. The
Dockerfile fetches the source itself via `ADD <git url>#<ref>` (BuildKit's
native git source), so there's no local checkout to manage — `docker buildx
bake` alone produces the image.

## Important: this is loopback-only by design, not a bug

`dsh` can execute model-generated shell commands. Its own web-app flag
parser (`packages/bundle/web-app/src/startup.ts`) hard-refuses `--host
0.0.0.0`:

> "it would expose remote code execution to the network; use 127.0.0.1
> instead"

This image respects that guard — it does not run a `0.0.0.0` proxy or
sidecar in front of the loopback-bound process, which would silently defeat
it. To reach the UI from the container's host, `docker-compose.yml` uses
`network_mode: host` (Linux-only): the container's loopback becomes the
host's loopback, so `http://localhost:3080` works exactly as if you'd run
`dsh web` on the host directly — no wider exposure than upstream intends.
See that file's comments for the full reasoning and the tradeoffs of host
networking.

Also review upstream's [`SAFETY.md`](https://github.com/deepseek-ai/deepseek-harness/blob/main/SAFETY.md)
before running this anywhere — it's developer-preview software, unaudited,
and the recommended posture is "disposable VM or container, least
privilege," which containerizing it satisfies but doesn't replace.

## Quick start

```bash
docker buildx bake            # or: bash bake.sh
docker compose up dsh
```

Open `http://localhost:3080`, then **Settings → Models** to add a
[DeepSeek API key](https://platform.deepseek.com/) — same first-run steps as
the [upstream Web UI guide](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/guide/index.md).
`./data/workspace` (bind-mounted to `/workspace`) is what you pick as the
"workspace" inside the UI; `./data/dsh-home` persists your API key, profiles,
and session history across container recreation.

## Using other model providers (e.g. Ollama)

DeepSeek is the only provider with a dedicated card. Anything else —
including a local Ollama server — goes through **Settings → Models → Add a
custom provider** (see upstream's
[model configuration guide](https://github.com/deepseek-ai/deepseek-harness/blob/main/docs/user/guide/providers.md)).
That form has four required fields: a lowercase **Provider ID**, a **base
URL**, an **API protocol**, and a **credential** — plus at least one model
under **Model catalog**.

For Ollama's OpenAI-compatible endpoint:

- **Base URL**: `http://localhost:11434/v1` — reachable as-is because this
  image's `dsh` service runs with `network_mode: host` (see above), so the
  container's `localhost` is the Docker host's `localhost`. If Ollama runs
  in its own container instead, use that container's service name/IP on a
  shared Docker network instead of `localhost`.
- **API protocol**: the OpenAI-compatible option.
- **Credential**: any non-empty placeholder. Ollama itself ignores it, but
  the field can't be blank — an empty one is exactly what produces
  `No API key for provider: ollama` / `PI_AI_ERROR` (a `MISSING_CREDENTIAL`
  error from the `pi-ai` model-request library `dsh` uses under the hood).
- **Models**: use **Fetch available models** to query Ollama's `/v1/models`
  directly, or add pulled model names (`ollama pull <name>`) by hand.

## How the source gets in

`dsh/Dockerfile`'s `deps` stage does:

```dockerfile
ADD "https://github.com/deepseek-ai/deepseek-harness.git#${DSH_GIT_REF}" .
```

instead of a `COPY . .` against a local checkout — BuildKit clones the repo
at build time, at whatever `DSH_GIT_REF` names (tag, branch, or commit SHA;
default is a pinned release tag, see `docker-bake.hcl`'s `DSH_GIT_REF`
variable). No local clone, `.dockerignore`, or build-context management
needed; the build context is just `dsh/` (the Dockerfile and
`entrypoint.sh`). Build against a different ref with:

```bash
DSH_GIT_REF=dsh-v0.1.2-alpha.5 bash bake.sh
```

Pin to a tag or commit for reproducible builds — upstream itself warns
"THERE WILL BE COMPATIBILITY-BREAKING CHANGES" on `main`.

## What the image does

- **Multi-stage build**: `deps` (`ADD` the source, then a full pnpm
  workspace install) → `build` (`pnpm run build` — `tsc`/`tsdown` across
  every package plus the web frontend) → `runtime` (the built tree only).
  No `tini` baked into the image — see "Security notes" below for how
  subprocess reaping is handled instead. The container starts as root and
  `entrypoint.sh` drops to an unprivileged `dsh` user before running
  anything — see "Security notes" for why root is needed first.
- **Debian (glibc), not Alpine — required, found the hard way**:
  `vendor/loader` resolves plugin packages at runtime through
  `node-addon-require-builtin`, a native addon that only ships glibc
  prebuilt binaries (`-linux-x64-gnu`/`-linux-arm64-gnu` in
  `pnpm-lock.yaml`, no `-musl` variant). On Alpine that addon silently has
  nothing to install, plugin resolution falls back to a plain `import()`
  that can't see pnpm's per-package `node_modules`, and the whole plugin
  tree fails to boot ("Cannot find package '@deepseek-ai/cordis-plugin-timer'").
  `native/landlock-run` does not push the other way — it's statically
  linked against musl, which makes it libc-agnostic at runtime (a static
  musl binary runs fine on a glibc host); it's the deciding constraint here,
  not a competing one.
- **`node-pty`** (a real workspace dependency, listed under `allowBuilds` in
  upstream's `pnpm-workspace.yaml`) needs a native build; the `deps` stage
  installs `python3 make g++` for it (Debian's node image already carries
  `libc6-dev`, unlike Alpine where a separate `linux-headers` package was
  needed).
- **No pruning**: the runtime stage ships the full built `/app` tree. The
  workspace's `workspace:^` links make a partial prune (e.g. `pnpm deploy`)
  unsafe without upstream declaring `"deploy"` config for it, which it
  currently doesn't — simple and correct over small.
- **`DSH_HOME`** (`/home/dsh/.dsh` — profiles, credentials, sessions) and
  **`/workspace`** (the project directory `dsh` operates on) are both
  declared volumes; `docker-compose.yml` binds them to `./data/dsh-home` and
  `./data/workspace`.

## Runtime configuration

`entrypoint.sh` reads these (all optional) and translates them into `dsh
web` flags — see that file's header comment for the authoritative list:

| Variable | Default | Description |
|---|---|---|
| `DSH_PORT` | `3080` (dsh's own default) | `--port`; `0` lets the OS pick a free one |
| `DSH_HOST` | *(unset → loopback)* | `--host`; **refused if `"0.0.0.0"`** — see above |
| `DSH_TRUSTED_HOSTS` | *(unset)* | space-separated `--trusted-host` values (extra `/api` browser-trust authorities) |
| `DSH_HOME` | `/home/dsh/.dsh` (image `ENV`, don't override lightly) | profiles/credentials/sessions root |
| `DSH_WORKSPACE` | `/workspace` (image `ENV`) | directory `dsh` treats as its workspace root |

Any other `dsh` entry mode still works by overriding the container command —
`entrypoint.sh` only rewrites argv when it's `web`:

```bash
docker run --rm -it --init ghcr.io/arasemco/dsh:latest dsh --profile headless "run the tests"
```

(See upstream `apps/cli/README.md#entry-modes` for the full list —
`--profile acp`, `--profile sdk`, `plugin`, etc.)

## Building

Images are built with `docker buildx bake`, not `docker build` or `docker
compose build`:

```bash
bash bake.sh                      # build the default group (the "dsh" target)
bash bake.sh --push               # build and push to REGISTRY
bash bake.sh --print               # resolve and print the full config, no build
```

`bake.sh` sets `GIT_SHA`/`GIT_REF` from *this* repo's local git checkout
(the packaging files, not upstream's source) before invoking `docker buildx
bake -f docker-bake.hcl` — used only for the OCI revision/ref.name labels.

### Bumping the base image

The Node base is pinned by digest, not just tag. Both `dsh/Dockerfile`'s
`NODE_REF` default and `docker-bake.hcl`'s `NODE_BASE.digest` currently
carry a **placeholder digest** — this was written without registry network
access. Resolve the real one before your first build:

```bash
docker pull node:22-bookworm-slim --platform linux/amd64
docker inspect --format='{{index .RepoDigests 0}}' node:22-bookworm-slim
```

and update both files. Keep the tag `>=22.19` per upstream's
`package.json` `engines.node` constraint (`^22.19.0 || >=24.0.0`) — and
keep it a Debian/glibc tag, not Alpine (see "What the image does" above).

### Bumping dsh itself

Update `DSH_GIT_REF` in `docker-bake.hcl` to the tag/commit you want to
build. `PNPM_VERSION` must match the `"packageManager"` field in that ref's
root `package.json` (`pnpm@11.7.0` as of `dsh-v0.1.1-rc.2`) — mismatches
will fail `corepack prepare`. `DSH_VERSION` is a label/tag suffix only;
keep it in sync with `DSH_GIT_REF`.

## Layout

```
.
├── dsh/
│   ├── Dockerfile       # deps (ADD source + install) / build / runtime stages
│   └── entrypoint.sh    # translates DSH_* env vars into `dsh web` flags, execs dsh
├── docker-bake.hcl       # build definition (target, labels, base pin, DSH_GIT_REF)
├── bake.sh               # wraps buildx bake, injects GIT_SHA/GIT_REF
├── docker-compose.yml     # host-networked "dsh" service + an isolated variant for CI smoke tests
├── .github/workflows/
│   └── docker-build-push.yml  # CI: multi-registry build and push workflow
├── LICENSE                # MIT (this packaging; upstream dsh has its own)
├── .gitignore             # ignores ./data (bind-mounted volumes)
└── README.md              # this file
```

## Security notes

- The container **starts as root**, but `dsh` itself never runs as root:
  `entrypoint.sh` chowns `DSH_HOME`/`DSH_WORKSPACE` (bind-mounted host
  directories that Docker may have auto-created as root, which an
  unprivileged process can't fix on its own) then drops to a dedicated
  `dsh` system user via `setpriv` before exec'ing anything — least
  privilege from that point on, per upstream `SAFETY.md` (developer-preview
  software that executes model-generated commands). If you don't trust
  entrypoint.sh's chown step, mount already-`dsh`-owned directories instead
  and it's a no-op beyond re-asserting ownership.
- Loopback-only by design; see the section above. Don't add a
  `0.0.0.0`-listening proxy in front of this image.
- `docker-compose.yml` sets `init: true` on both services, so Docker's own
  built-in `tini` is PID 1 — `docker stop` reaches `dsh` and the
  subprocesses it spawns for tool calls instead of leaving orphans. Running
  the image directly, pass `docker run --init` for the same reason.
- Treat the container the same way upstream recommends treating the
  process: disposable, least-privilege, backed-up data outside it (that's
  what the `DSH_HOME`/`workspace` volumes are for), and don't hand it
  credentials or a workspace you wouldn't want a buggy or misconfigured
  model-generated command to reach.

## Links

- [DeepSeek Harness (upstream)](https://github.com/deepseek-ai/deepseek-harness)
- [Upstream SAFETY.md](https://github.com/deepseek-ai/deepseek-harness/blob/main/SAFETY.md)

## License

MIT — see upstream `deepseek-harness`'s own [`LICENSE`](https://github.com/deepseek-ai/deepseek-harness/blob/main/LICENSE)
for the software this packages; these Docker files themselves are MIT too.
