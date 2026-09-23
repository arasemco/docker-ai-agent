# syntax=docker/dockerfile:1
# =============================================================================
# DeepSeek Harness (dsh) — Web UI container image
# =============================================================================
# Upstream (github.com/deepseek-ai/deepseek-harness) ships no Docker support
# as of this writing — no Dockerfile, docker-compose.yml, or docker-bake.hcl
# anywhere in the repo. This Dockerfile builds the project from source using
# exactly the "Run from source" steps in the upstream root README:
#
#   git clone .../deepseek-harness.git && cd deepseek-harness
#   pnpm install
#   pnpm run build
#   pnpm dsh web
#
# SAFETY (read before changing --host handling): dsh's own web-app flag
# parser (packages/bundle/web-app/src/startup.ts) hard-refuses `--host
# 0.0.0.0` — "it would expose remote code execution to the network; use
# 127.0.0.1 instead". dsh can execute model-generated shell commands, so this
# is a deliberate guard, not an oversight (see upstream SAFETY.md). This
# image respects it: the container binds loopback-only by default and never
# works around the guard with a 0.0.0.0 proxy/sidecar. See docker-compose.yml
# and the top-level README for the supported way to reach the UI from the
# container's host (`network_mode: host`).
#
# Base image pinned by digest, passed in from docker-bake.hcl — see that
# file's NODE_BASE variable for the actual name:tag@digest value.
#
# Debian ("bookworm-slim"), NOT Alpine — this matters and was verified the
# hard way. vendor/loader resolves plugin packages at runtime through
# node-addon-require-builtin, a native addon that hooks Node's internal
# module loader; without it, plugin resolution silently falls back to a
# plain `import(name)` that cannot see pnpm's per-package node_modules and
# the whole plugin tree fails to boot ("Cannot find package
# '@deepseek-ai/cordis-plugin-timer'"). That addon publishes only
# "-linux-x64-gnu"/"-linux-arm64-gnu" prebuilt binaries (glibc) — no "-musl"
# variant exists (checked pnpm-lock.yaml directly) — so it silently has
# nothing to install on Alpine. native/landlock-run does NOT force the
# opposite choice: its own README says it's statically linked against musl,
# which makes it libc-agnostic at runtime (a static musl binary runs fine on
# a glibc host); it's the deciding constraint here, not a competing one.
#
# NOTE: the digest below is a PLACEHOLDER — this file was written without
# registry network access. Resolve the real one before building:
#   docker pull node:22-bookworm-slim --platform linux/amd64
#   docker inspect --format='{{index .RepoDigests 0}}' node:22-bookworm-slim
# and paste the sha256:... value here and in docker-bake.hcl's NODE_BASE.
ARG NODE_REF=docker.io/library/node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5

ARG PNPM_VERSION=11.7.0
# ^ must match the "packageManager" field in the upstream repo's root
# package.json (pnpm@11.7.0 at the time this was written) — corepack
# installs exactly this version, no floating "latest".

ARG DSH_GIT_REF=dsh-v0.1.1-rc.2
# ^ tag, branch, or commit SHA to build — fetched directly via `ADD` below
# (BuildKit's native git source, verified working against this repo: a
# pinned commit resolves even though it isn't in the shallow default fetch).
# Pin to a tag or commit for reproducible builds; upstream itself warns
# "THERE WILL BE COMPATIBILITY-BREAKING CHANGES" on main, so avoid tracking
# a branch in anything but local experimentation.
#
# `--keep-git-dir=true` on that ADD is required, not cosmetic:
# scripts/client-build-environment.ts's repositoryCommitHash() shells out to
# `git rev-parse HEAD` during `pnpm run build` to embed a commit hash in the
# web client bundle, and fails the whole build if there's no .git (verified
# — this is exactly what broke before this was added). The build stage
# below removes .git again once the build's done, so it never reaches the
# runtime image.


# =============================================================================
# deps — install the full pnpm workspace. This monorepo's ~50+ internal
# @deepseek-ai/* packages all resolve each other via workspace:^ links, and
# the build step (tsc project references across the whole tree) needs every
# package's devDependencies present, so there is no safe partial install
# before building — this mirrors upstream's own documented build sequence.
#
# CI=true makes the workspace root's own postinstall (`scripts/install-
# lefthook.mjs`, a git-hooks installer wired up via the root package.json's
# "postinstall" script — verified against upstream source) exit immediately
# instead of erroring: it checks `CI === 'true'` / `GITHUB_ACTIONS === 'true'`
# before touching git at all, independent of the .git dir that
# `--keep-git-dir=true` below leaves in place (that's kept for a different
# reason — see the DSH_GIT_REF comment above).
# =============================================================================
FROM ${NODE_REF} AS deps

ARG PNPM_VERSION
ARG DSH_GIT_REF
ENV CI=true \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH

# python3/make/g++: node-pty (packages/*/pwsh-local and terminal deps) needs
# a native build via node-gyp — see the "allowBuilds" section of
# pnpm-workspace.yaml, which lists it as a required build script. Debian's
# node image already carries libc6-dev, so no separate headers package is
# needed the way Alpine's linux-headers would be.
# git: some workspace tooling shells out to `git rev-parse` at install time
# (see install-lefthook.mjs) and no-ops cleanly when it's missing a repo, but
# keeping git present avoids relying on that fallback path.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 make g++ git ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable \
    && corepack prepare "pnpm@${PNPM_VERSION}" --activate

WORKDIR /app
ADD --keep-git-dir=true "https://github.com/deepseek-ai/deepseek-harness.git#${DSH_GIT_REF}" .

RUN pnpm install --frozen-lockfile


# =============================================================================
# build — compiles every workspace package (build:lib, tsc + tsdown) and the
# web frontend (build:web) — exactly upstream's "pnpm run build". Needs the
# .git dir kept by the ADD above (see that comment); removed again right
# after so it never lands in the runtime image.
# =============================================================================
FROM deps AS build

RUN pnpm run build \
    && rm -rf .git


# =============================================================================
# runtime — same Node/Debian base as the build stage: node-addon-require-
# builtin (see the SAFETY/base-image comment above) only ships glibc
# prebuilt binaries, so the runtime stage has to be glibc too, not just the
# build stage.
#
# Ships the full built /app tree rather than a pruned one: pnpm's
# workspace:^ links make a partial prune unsafe without `pnpm deploy`
# support, which the upstream package.json files don't currently declare
# (no "deploy" config). This keeps the image simple and correct at the cost
# of size — see the top-level README for what that costs in practice.
# =============================================================================
FROM ${NODE_REF} AS runtime

# curl: the "test" stage's DeepSeek API check. ca-certificates: dsh talks to the DeepSeek API
# (and whatever OpenAI-compatible endpoint you configure) over HTTPS.
# util-linux: provides setpriv, which entrypoint.sh uses to drop from root
# to "dsh" — listed explicitly rather than assumed, even though it's a
# Debian "Required"-priority package normally pulled in already.
#
# dsh:dsh is pinned to uid:gid 1000:1000 on purpose, not left to
# --system's arbitrary allocation — 1000 is the UID/GID of the first
# normal user on virtually every Linux distro, so a bind-mounted
# DSH_HOME/DSH_WORKSPACE (./data/dsh-home, ./data/workspace) usually
# lands already owned by a UID the container's "dsh" user matches
# exactly, with no PUID/PGID remapping dance required.
#
# The official Node base image already creates a "node" user/group at
# 1000:1000 (every variant, since Node 10) — claiming 1000 with a plain
# `useradd --uid 1000` would collide with that. Rather than assume
# either way (and silently break if upstream ever changes it), check
# for an existing 1000:1000 account first and rename it to "dsh" in
# place (keeping its already-initialized home directory), only falling
# back to creating a fresh one if 1000 is actually free.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && existing_group="$(getent group 1000 | cut -d: -f1)" \
    && if [ -n "$existing_group" ]; then groupmod --new-name dsh "$existing_group"; else groupadd --gid 1000 dsh; fi \
    && existing_user="$(getent passwd 1000 | cut -d: -f1)" \
    && if [ -n "$existing_user" ]; then usermod --login dsh --gid dsh --home /home/dsh --move-home --shell /bin/sh "$existing_user"; else useradd --uid 1000 --gid dsh --create-home --home-dir /home/dsh --shell /bin/sh dsh; fi \
    && mkdir -p /workspace \
    && chown -R dsh:dsh /workspace /home/dsh

WORKDIR /app
COPY --from=build --chown=dsh:dsh /app /app
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=644 healthcheck.mjs /usr/local/lib/dsh/healthcheck.mjs

# apps/cli's package.json declares "bin": {"dsh": "lib/bin.js"}, but that
# only gets symlinked into a node_modules/.bin by pnpm for packages that
# depend on @deepseek-ai/dsh — nothing in this workspace does (apps/cli is
# a build target, not a dependency), so no such symlink is ever created.
# Write the wrapper directly instead of assuming one exists on PATH
# (verified: it doesn't). apps/cli/lib/bin.js does carry its own
# "#!/usr/bin/env node" shebang from src/bin.ts, but this avoids depending
# on tsdown having also preserved its executable bit.
RUN printf '#!/bin/sh\nexec node /app/apps/cli/lib/bin.js "$@"\n' > /usr/local/bin/dsh \
    && chmod +x /usr/local/bin/dsh

ENV NODE_ENV=production \
    DSH_HOME=/home/dsh/.dsh \
    DSH_WORKSPACE=/workspace

# No USER instruction — the container starts as root on purpose.
# entrypoint.sh needs root to chown DSH_HOME/DSH_WORKSPACE (bind-mounted
# host directories that Docker may have auto-created as root — see that
# file's header comment) before it drops to the unprivileged "dsh" user via
# setpriv and execs dsh. dsh itself never runs as root; this is the same
# root-then-drop shape common init scripts use for exactly this bind-mount
# ownership problem.
WORKDIR /workspace

# /home/dsh/.dsh: profiles, credentials (API keys entered via Settings),
# sessions — everything the "Run docs/user/guide/index.md" quick start
# writes. /workspace: the project directory dsh operates on (its default
# workspace root is the invoking directory).
VOLUME ["/home/dsh/.dsh", "/workspace"]

# Loopback-only by design (see the SAFETY note at the top of this file) —
# EXPOSE documents the port for `network_mode: host`/introspection, it does
# not itself publish anything to a bridge network.
EXPOSE 3080

# `GET /` is 401 without a signed-in browser session, so a plain curl
# can't pass. healthcheck.mjs loads dsh's stored session-signing secret from
# $DSH_HOME/.credentials.yaml, signs a short-lived cookie with it, and
# requires a 200 — see that file's header.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --start-interval=5s \
    CMD ["node", "/usr/local/lib/dsh/healthcheck.mjs"]

# No tini baked into the image: dsh spawns subprocesses for tool calls
# (bash, subagents, etc.) that need a real PID 1 to reap them and forward
# signals correctly on `docker stop`. Rather than install one per base
# image, this relies on Docker's own built-in init — `init: true` in
# docker-compose.yml, or `docker run --init` — which injects tini at the
# container-runtime level regardless of what's in the image.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["web"]


# =============================================================================
# test — loads the real DeepSeek API key the same way the running container
# does and checks it works. Built only by the "test" target in
# docker-bake.hcl (`make test`); never pushed.
#
# dsh keeps the key in $DSH_HOME/.credentials.yaml under refs.DEEPSEEK_API_KEY
# (upstream packages/credentials/credentials-local: `version: 1` / `refs:` /
# `DEEPSEEK_API_KEY: sk-...`), which is what Settings → Models writes into
# the dsh_home volume. That whole file comes in as the "dsh_credentials"
# BuildKit secret, mounted where dsh itself looks for it. A secret mount is
# never written into a layer.
#
# uid/gid 1000 + mode 0600 on the mount are required: credentials-local
# refuses to read a credentials file with any group/other permission bit set.
# DEEPSEEK_API_KEY is deliberately NOT set in the environment. The inherited
# environment outranks the file, so setting it would skip the file load that
# this stage exists to test.
#
# Two checks:
#   1. GET https://api.deepseek.com/models with the key must return 200, so
#      the key itself is valid.
#   2. `dsh --profile headless` must finish a one-line task (exit 0), so dsh
#      really resolved the key from the file and completed a model round trip.
#
# DSH_HOME points at a scratch directory, not the image's /home/dsh/.dsh:
# the headless profile writes its profile/session files there on first use,
# and the secret mount inside it is read-only.
# =============================================================================
FROM runtime AS test

ENV DSH_HOME=/tmp/dsh-test/home
RUN install -d -o dsh -g dsh -m 700 /tmp/dsh-test/home /tmp/dsh-test/workspace
WORKDIR /tmp/dsh-test/workspace

RUN --mount=type=secret,id=dsh_credentials,target=/tmp/dsh-test/home/.credentials.yaml,uid=1000,gid=1000,mode=0600,required=true <<'EOF'
set -eu
creds="$DSH_HOME/.credentials.yaml"

key="$(awk '
  /^refs:/ { in_refs = 1; next }
  in_refs && /^[^ \t#]/ { in_refs = 0 }
  in_refs && $1 == "DEEPSEEK_API_KEY:" {
    v = $2; gsub(/^["\047]|["\047]$/, "", v); print v; exit
  }' "$creds")"
if [ -z "$key" ]; then
  echo "test: no refs.DEEPSEEK_API_KEY in the dsh_credentials secret" >&2
  exit 1
fi

# The header goes in on stdin, so the key never shows up in argv.
status="$(printf 'Authorization: Bearer %s\n' "$key" \
  | curl -sS -o /dev/null -w '%{http_code}' -H @- https://api.deepseek.com/models)"
unset key
if [ "$status" != 200 ]; then
  echo "test: DeepSeek API rejected the key (GET /models -> HTTP $status)" >&2
  exit 1
fi
echo "test: API key valid (GET /models -> 200)"

timeout 300 setpriv --reuid=dsh --regid=dsh --init-groups \
  env HOME=/home/dsh USER=dsh LOGNAME=dsh \
  dsh --profile headless "Reply with exactly the word OK and nothing else." \
  > /tmp/dsh-test/answer
echo "test: dsh headless answered: $(cat /tmp/dsh-test/answer)"
grep -qi 'ok' /tmp/dsh-test/answer
EOF
