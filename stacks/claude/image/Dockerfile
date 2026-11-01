# syntax=docker/dockerfile:1
# =============================================================================
# claude — Claude Code on agent-base
# =============================================================================
# agent-base provides the sandbox: Debian base, agent user, s6 supervision, the
# rootless Docker daemon, the toolchain, hooks and healthcheck. This image adds:
#
#   * Node 22 — agent-base ships Debian's Node 18.20, while
#     @anthropic-ai/claude-code declares engines ">=22.0.0". The runtime comes
#     from the official Node image, pinned by digest, so no third-party apt
#     repository is needed.
#   * @anthropic-ai/claude-code from npm, pinned to an exact version.
#   * services.d/agent/run — Claude Code is an interactive TUI with no local
#     server mode, so the agent service supervises the idler and the CLI runs
#     on demand through `make exec`.
#
# No credentials are baked in: ANTHROPIC_API_KEY and CLAUDE_CODE_OAUTH_TOKEN
# are passed at run time. See docs/configuration.md.
# =============================================================================

ARG AGENT_BASE=agent-base:1.5.0

# Official Node 22 image, used only as the source of the runtime. Pinned by
# digest; it is the same glibc distribution as agent-base.
ARG NODE_REF=docker.io/library/node:22-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da

ARG CLAUDE_VERSION=2.1.316

# -----------------------------------------------------------------------------
# node — the runtime pieces only: the node binary and npm. corepack, yarn and the
# development headers are not copied, because nothing here uses them.
# -----------------------------------------------------------------------------
FROM ${NODE_REF} AS node

# -----------------------------------------------------------------------------
# claude
# -----------------------------------------------------------------------------
FROM ${AGENT_BASE} AS claude

ARG CLAUDE_VERSION

# /usr/local/bin comes first on PATH, so this Node 22 wins over Debian's
# /usr/bin/node 18 for the shell and for everything Claude Code starts.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -sf /usr/local/bin/node /usr/local/bin/nodejs \
    && node --version \
    && npm --version

# Global install as root: the package puts its platform binary under
# /usr/local/lib/node_modules/@anthropic-ai/claude-code and links
# /usr/local/bin/claude to it. --version fails the build if the install is
# broken.
RUN --mount=type=cache,target=/root/.npm \
    npm install --global --no-fund --no-audit --no-update-notifier "@anthropic-ai/claude-code@${CLAUDE_VERSION}" \
    && claude --version

# Claude Code keeps settings, credentials, transcripts and .claude.json under
# CLAUDE_CONFIG_DIR, so one directory is one volume. Mode 0700 because
# .credentials.json lives there.
RUN install -d -o 1000 -g 1000 -m 700 "/home/agent/.claude"

ENV CLAUDE_CONFIG_DIR=/home/agent/.claude

# Interactive TUI, no local server mode: keep the sandbox up and start the CLI
# with `make exec PROFILE=claude`. See services.d/agent/run.
COPY --chmod=755 services.d/agent/run /etc/services.d/agent/run
