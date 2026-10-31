# syntax=docker/dockerfile:1
# =============================================================================
# dsh — the DeepSeek Harness (dsh) Web UI on top of agent-base
# =============================================================================
# agent-base provides the sandbox: Debian base, agent user, s6 services, rootless
# Docker daemon, toolchain, entrypoint, hooks and healthcheck. This image adds
# what dsh needs on top:
#
#   * Node 22 — agent-base ships Debian's Node 18.20, while @deepseek-ai/dsh
#     declares engines "^22.19.0 || >=24". Node comes from its official image,
#     pinned by digest, in a separate build stage; only the runtime pieces are
#     copied into the final image, so there is no second distribution and no
#     third-party apt repository.
#   * @deepseek-ai/dsh from npm, pinned to an exact version.
#   * The hook that turns DSH_* variables into `dsh web` options.
#   * A healthcheck that proves the UI answers an authenticated request.
#
# dsh is loopback-only by design: its web server refuses wildcard bind addresses
# and listens on 127.0.0.1. The compose file therefore uses host networking so
# the UI answers on the host's own loopback; see docs/configuration.md.
# =============================================================================

ARG AGENT_BASE=agent-base:1.4.1

# Official Node 22 image, used only as the source of the runtime. Pinned by
# digest; it is the same glibc distribution as agent-base, so the binary needs no
# compatibility layer.
ARG NODE_REF=docker.io/library/node:22-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da

ARG DSH_VERSION=0.2.1-rc.5

# -----------------------------------------------------------------------------
# node — the runtime pieces only: the node binary and npm. corepack, yarn and the
# development headers are not copied, because nothing here uses them.
# -----------------------------------------------------------------------------
FROM ${NODE_REF} AS node

# -----------------------------------------------------------------------------
# runtime
# -----------------------------------------------------------------------------
FROM ${AGENT_BASE} AS runtime

ARG DSH_VERSION

# /usr/local/bin comes first on PATH, so this Node 22 wins over Debian's
# /usr/bin/node 18 for the shell and for everything dsh starts.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -sf /usr/local/bin/node /usr/local/bin/nodejs \
    && node --version \
    && npm --version

# Global install as root: /usr/local/lib/node_modules/@deepseek-ai/dsh with
# /usr/local/bin/dsh linked to its lib/bin.js. dsh's native dependencies ship
# prebuilt binaries, so the install itself needs no compiler.
RUN --mount=type=cache,target=/root/.npm \
    npm install --global --no-fund --no-audit --no-update-notifier "@deepseek-ai/dsh@${DSH_VERSION}" \
    && dsh --version

# DSH_HOME holds profiles, credentials and sessions. Created here owned by the
# agent user with mode 0700 (the credentials file inside is private), so a named
# volume mounted over it inherits that ownership.
RUN install -d -o 1000 -g 1000 -m 700 "/home/agent/.dsh"

# The healthcheck signs a browser-session cookie with the secret dsh stores in
# $DSH_HOME/.credentials.yaml and requires HTTP 200, because the UI answers 401
# until a browser signs in through the launch token.
COPY --chmod=644 healthcheck.mjs /usr/local/lib/dsh-healthcheck.mjs

# Flag translation runs as an agent-entrypoint hook, before the CLI starts, and
# rewrites the argument list (`web` becomes `web --no-open --port …`).
COPY --chmod=755 hooks/20-dsh-flags.sh /etc/agent-entrypoint.d/20-dsh-flags.sh

ENV DSH_HOME=/home/agent/.dsh \
    DSH_WORKSPACE=/home/agent/workspace \
    DSH_PORT=3080 \
    DSH_PACKAGE=/usr/local/lib/node_modules/@deepseek-ai/dsh/package.json \
    AGENT_WORKSPACE=/home/agent/workspace \
    AGENT_CMD=dsh

# Loopback-only, reachable through host networking (see the compose file);
# EXPOSE documents the port for readers and tooling.
EXPOSE 3080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --start-interval=5s --retries=3 \
    CMD ["node", "/usr/local/lib/dsh-healthcheck.mjs"]


# =============================================================================
# test — loads a real credentials file the same way the running container does
# and checks that dsh can use it. Built only by the "test" bake target
# (`make test`); never pushed.
#
# dsh stores the API key in $DSH_HOME/.credentials.yaml under
# refs.DEEPSEEK_API_KEY (written by Settings -> Models). That file comes in as the
# "dsh_credentials" BuildKit secret, mounted where dsh looks for it: a secret
# mount never lands in a layer.
#
# uid/gid 1000 and mode 0600 are required — credentials-local refuses a file with
# any group or other permission bit set.
#
# Two checks: GET https://api.deepseek.com/models must return 200 with the key,
# and `dsh --profile headless` must complete a one-line task, which proves dsh
# resolved the key from the file and finished a model round trip.
# =============================================================================
FROM runtime AS test

ENV DSH_HOME=/tmp/dsh-test/home
RUN install -d -m 700 /tmp/dsh-test/home /tmp/dsh-test/workspace
WORKDIR /tmp/dsh-test/workspace

RUN --mount=type=secret,id=dsh_credentials,target=/tmp/dsh-test/home/.credentials.yaml,uid=1000,gid=1000,mode=0600,required=true <<'SCRIPT'
set -eu
creds="${DSH_HOME}/.credentials.yaml"

key="$(awk '
  /^refs:/ { in_refs = 1; next }
  in_refs && /^[^ \t#]/ { in_refs = 0 }
  in_refs && $1 == "DEEPSEEK_API_KEY:" {
    v = $2; gsub(/^["\047]|["\047]$/, "", v); print v; exit
  }' "${creds}")"
if [ -z "${key}" ]; then
    echo "test: no refs.DEEPSEEK_API_KEY in the dsh_credentials secret" >&2
    exit 1
fi

# The header goes in on stdin so the key never appears in argv.
status="$(printf 'Authorization: Bearer %s\n' "${key}" \
    | curl -sS -o /dev/null -w '%{http_code}' -H @- https://api.deepseek.com/models)"
unset key
if [ "${status}" != 200 ]; then
    echo "test: DeepSeek API rejected the key (GET /models -> HTTP ${status})" >&2
    exit 1
fi
echo "test: API key valid (GET /models -> 200)"

timeout 300 dsh --profile headless "Reply with exactly the word OK and nothing else." \
    > /tmp/dsh-test/answer
echo "test: dsh headless answered: $(cat /tmp/dsh-test/answer)"
grep -qi 'ok' /tmp/dsh-test/answer
SCRIPT
