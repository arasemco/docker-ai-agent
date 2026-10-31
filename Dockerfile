# syntax=docker/dockerfile:1
# =============================================================================
# opencode — the OpenCode CLI/Web UI on top of agent-base
# =============================================================================
# Everything shared (Debian + Node/npm, the agent user, rootless Docker, the
# toolchain, the entrypoint and healthcheck) comes from agent-base. This file
# adds only what is OpenCode-specific:
#
#   * the opencode-ai package from npm, pinned to an exact version
#   * the seeded provider config (Ollama, see opencode.jsonc)
#   * AGENT_CMD=opencode, so the base entrypoint exec's it with the args from
#     docker-compose.yml (`web --port ... --hostname 0.0.0.0`)
#
# Build:
#   docker compose up -d --build
#   bash bake.sh            # or via bake, tagged ${REGISTRY}/opencode
# =============================================================================

# Pinned to a registry tag, not :latest, so a rebuild is reproducible. Bump
# deliberately (and retest) when agent-base changes.
ARG AGENT_BASE=git.omesa.net/asemo/agent-base:1.1.0
FROM ${AGENT_BASE}

# Exact opencode-ai version (`npm view opencode-ai versions`); a dist-tag
# would float. 1.19.5 is npm's current "latest".
ARG OPENCODE_VERSION=1.19.5

USER root

# The official npm package (not the curl installer): it ships per-platform
# binaries as optionalDependencies and a postinstall that links the right one.
# Installed as root so it lands in /usr/local and is on the agent user's PATH.
RUN --mount=type=cache,target=/root/.npm \
    npm install --global --no-fund --no-audit --no-update-notifier "opencode-ai@${OPENCODE_VERSION}" \
    && opencode --version

# OpenCode's state directories must exist in the image already owned by the
# agent user: a fresh named volume mounted on a path the image doesn't have
# comes up root-owned, and opencode then dies with
# "PermissionDenied: FileSystem.open (.../log/opencode.log)". install -d sets
# the ownership explicitly (COPY would create missing parents as root).
RUN install -d -o 1000 -g 1000 \
        "/home/agent/.config/opencode" \
        "/home/agent/.local/share/opencode" \
        "/home/agent/.local/state/opencode" \
        "/home/agent/.cache/opencode" \
    # `opencode --version` above ran as root and already created log/repos
    # inside ~/.local/share/opencode, so fix the whole tree, not just the tops.
    && chown -R 1000:1000 "/home/agent/.local" "/home/agent/.config" "/home/agent/.cache"

# Default provider config, seeded into the config volume on first use. A
# mounted volume hides this file once it has its own config, which is
# intended: config is editable state, not an immutable default.
COPY --chown=1000:1000 opencode.jsonc /home/agent/.config/opencode/opencode.jsonc

# NOTE: no `USER` switch here. s6-overlay's /init is PID 1 as root and drops
# to the agent user per service (services.d/agent/run and services.d/dockerd/run
# in agent-base), so the image must stay root at this point.

# The base entrypoint runs "$AGENT_CMD $@" for every command, so the compose
# `command:` supplies the subcommand and flags.
ENV AGENT_CMD=opencode

EXPOSE 4096
