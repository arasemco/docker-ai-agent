# docker-dsh

[![Build and push Docker images](https://github.com/arasemco/docker-dsh/actions/workflows/docker-build-push.yml/badge.svg)](https://github.com/arasemco/docker-dsh/actions/workflows/docker-build-push.yml)
[![GHCR: dsh](https://img.shields.io/badge/ghcr.io-dsh-blue?logo=docker)](https://github.com/arasemco/docker-dsh/pkgs/container/dsh)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)
[![Debian base](https://img.shields.io/badge/base-debian%20bookworm--slim-A81D33?logo=debian)](https://www.debian.org)

A container image for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
(`dsh`). Upstream publishes the CLI to npm as
[`@deepseek-ai/dsh`](https://www.npmjs.com/package/@deepseek-ai/dsh) (its
README runs it with `npx @deepseek-ai/dsh web`) but ships no container
image; this image installs that package at a pinned version, and
`docker buildx bake` alone produces it.

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
`./data/workspace` (bind-mounted to `/home/dsh/workspace`) is what you pick as the
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

## How dsh gets in

`dsh/Dockerfile` runs

```dockerfile
npm install --global "@deepseek-ai/dsh@${DSH_VERSION}"
```

which is the same package `npx @deepseek-ai/dsh` would fetch, installed once at
build time instead of on every container start, so the version is pinned and
the container boots without registry access. `DSH_VERSION` (in
`docker-bake.hcl`) is an exact npm version; build a different one with:

```bash
DSH_VERSION=0.1.7-rc.1 bash bake.sh
```

Pin exact versions rather than dist-tags — upstream warns "THERE WILL BE
COMPATIBILITY-BREAKING CHANGES". The minimum is `0.1.5-rc.3`: the npm build
of `0.1.2-rc.1` crashes on `dsh web` ("user patch-layer watching requires the
Cordis HMR service").

## What the image does

- **Unprivileged user**: `DSH_USER`/`DSH_UID`/`DSH_GID` build args
  (default `dsh`, 1000:1000; relabels the base image's `node` user). Root is
  used only for package installation and user creation, then `USER dsh`
  with `WORKDIR ~/workspace`.
- **Dev tooling** for the shell commands the agent runs: `bash git gh jq
  procps nano shellcheck gnupg uv`, Python 3 (`python3`, `pip`, `venv`),
  plus node/npm from the base. dsh itself is a global npm install; no
  compiler toolchain is needed. No `tini` baked in — see "Security notes".
- **Rootless Docker**: Docker Engine (`DOCKER_VERSION`, default `29.8.1`,
  with the buildx and compose plugins) runs inside the container as `dsh`
  under rootlesskit. `docker-entrypoint.sh` starts it before dsh, with the
  `fuse-overlayfs` storage driver; `DOCKER_HOST` points at
  `~/.docker/run/docker.sock` and the daemon log is
  `~/.docker/dockerd.log`. It needs the container to run with
  `seccomp:unconfined`, `systempaths=unconfined`, `/dev/fuse` and
  `/dev/net/tun` (set in `docker-compose.yml`); without them the daemon
  exits, a warning is logged, and dsh starts anyway. Debian's setuid
  `newuidmap`/`newgidmap` are replaced with `cap_setuid`/`cap_setgid` file
  capabilities; setuid, their write to `uid_map` fails with "Operation not
  permitted" inside a container.
- **Debian (glibc) base — required**: dsh's plugin loader goes through
  `node-addon-require-builtin`, a native addon that publishes only glibc
  prebuilt binaries (`-linux-x64-gnu`/`-linux-arm64-gnu`, no `-musl`
  variant). On a musl base such as Alpine, `dsh web` dies at boot with
  "--expose-internals is required for HMR service".
- **Healthcheck**: `GET /` answers 401 until a browser signs in through the
  `?token=` URL dsh prints, so a plain curl can't pass. `dsh/healthcheck.mjs`
  loads dsh's stored session-signing secret from
  `$DSH_HOME/.credentials.yaml`, signs a short-lived cookie with it, and
  requires a 200.
- **`DSH_HOME`** (`/home/dsh/.dsh` — profiles, credentials, sessions) and
  **`DSH_WORKSPACE`** (`/home/dsh/workspace`, the project directory `dsh`
  operates on) are created in the image owned by `dsh`;
  `docker-compose.yml` binds them to `./data/dsh-home` and
  `./data/workspace`.

## Runtime configuration

`docker-entrypoint.sh` reads these (all optional) and translates them into `dsh
web` flags — see that file's header comment for the authoritative list:

| Variable | Default | Description |
|---|---|---|
| `DSH_PORT` | `3080` (dsh's own default) | `--port`; `0` lets the OS pick a free one |
| `DSH_HOST` | *(unset → loopback)* | `--host`; **refused if `"0.0.0.0"`** — see above |
| `DSH_TRUSTED_HOSTS` | *(unset)* | space-separated `--trusted-host` values (extra `/api` browser-trust authorities) |
| `DSH_HOME` | `/home/dsh/.dsh` (image `ENV`, don't override lightly) | profiles/credentials/sessions root |
| `DSH_WORKSPACE` | `/home/dsh/workspace` (image `ENV`) | directory `dsh` treats as its workspace root |
| `DSH_DOCKERD` | `1` | `0` skips starting the rootless Docker daemon |

Any other `dsh` entry mode still works: the container command is passed to
`dsh` as its arguments, and `docker-entrypoint.sh` only rewrites them when
it's `web`:

```bash
docker run --rm -it --init ghcr.io/arasemco/dsh:latest --profile headless "run the tests"
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

The Node base is pinned by digest, not just tag, in two places that must
agree: `dsh/Dockerfile`'s `NODE_REF` default and `docker-bake.hcl`'s
`NODE_BASE.digest`. Resolve a new digest with:

```bash
docker pull node:22-bookworm-slim --platform linux/amd64
docker inspect --format='{{index .RepoDigests 0}}' node:22-bookworm-slim
```

and update both files. Keep the tag `>=22.19` per upstream's
`package.json` `engines.node` constraint (`^22.19.0 || >=24.0.0`) — and
keep it a Debian/glibc tag, not Alpine (see "What the image does" above).

### Bumping dsh itself

Set `DSH_VERSION` in `docker-bake.hcl` (and the Dockerfile's `ARG`
default) to an exact version from `npm view @deepseek-ai/dsh versions`. It
is both what gets installed and the image tag.

### Testing the API key

```bash
make test
```

builds the Dockerfile's `test` stage (never pushed). It mounts dsh's
`.credentials.yaml` as a BuildKit secret, checks `refs.DEEPSEEK_API_KEY`
against `https://api.deepseek.com/models`, then runs a one-line
`dsh --profile headless` task that has to load the key from that file. The
file comes from `$DSH_CREDENTIALS`, else `./data/dsh-home/.credentials.yaml`,
else a temporary copy out of the `$DSH_VOLUME` volume (default
`deepseek-harness_dsh_home`).

## Layout

```
.
├── dsh/
│   ├── Dockerfile       # runtime (npm install) / test (API key check) stages
│   ├── docker-entrypoint.sh  # checks mounts, starts rootless dockerd, maps DSH_* env vars to `dsh web` flags, execs dsh
│   └── healthcheck.mjs  # signed-session-cookie HEALTHCHECK
├── docker-bake.hcl       # build definition (dsh + test targets, labels, base pin, DSH_VERSION)
├── bake.sh               # wraps buildx bake, injects GIT_SHA/GIT_REF
├── docker-compose.yml     # host-networked "dsh" service + an isolated variant for CI smoke tests
├── .github/workflows/
│   └── docker-build-push.yml  # CI: multi-registry build and push workflow
├── LICENSE                # MIT (this packaging; upstream dsh has its own)
├── .gitignore             # ignores ./data (bind-mounted volumes)
└── README.md              # this file
```

## Security notes

- The container **never runs as root**: the image's `USER` is `dsh`
  (uid:gid 1000:1000, configurable with the `DSH_USER`/`DSH_UID`/`DSH_GID`
  build args), so the entrypoint, `dsh`, the healthcheck, and `docker exec`
  all run unprivileged — least privilege per upstream `SAFETY.md`
  (developer-preview software that executes model-generated commands).
  Root is only used at build time. Named volumes inherit `dsh` ownership
  from the image; bind-mount directories must exist and be owned by
  1000:1000 before the first start (`make up` creates them), since Docker
  creates missing ones as root. `docker-entrypoint.sh` stops with the exact
  `chown` fix if they aren't writable.
- The in-container Docker daemon needs `seccomp:unconfined` and
  `systempaths=unconfined`, which widen what processes in the container
  (including model-generated commands) can reach in the kernel. The daemon
  itself stays unprivileged: it runs as `dsh` inside a user namespace, and
  containers it starts map to `dsh`'s subordinate uid range
  (`100000:65536`), not to host root. Leave those options off (and set
  `DSH_DOCKERD=0`) when the agent doesn't need Docker.
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
