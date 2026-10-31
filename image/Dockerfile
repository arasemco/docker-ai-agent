# syntax=docker/dockerfile:1
# =============================================================================
# opencode — the OpenCode CLI/Web UI on top of agent-base
# =============================================================================
# Everything shared (Debian + Node/npm, the agent user, s6 supervision, the
# rootless Docker daemon, the toolchain, hooks and healthcheck) comes from
# agent-base. This file adds only what is OpenCode-specific:
#
#   * the opencode-ai package from npm, pinned to an exact version
#   * its state directories, owned by the agent user
#   * AGENT_CMD=opencode, so the base's agent service execs it with the args
#     from the compose `command:` (`web --port … --hostname 0.0.0.0`)
#
# No provider config is baked in: which models you have, and where they live,
# is deployment-specific. See ../examples/config/ and the README.
# =============================================================================

# The shared base, pinned to a tag rather than :latest so a rebuild is
# reproducible. With no registry prefix this resolves to a locally built
# image; override AGENT_BASE to use a pushed one.
ARG AGENT_BASE=agent-base:1.1.0
FROM ${AGENT_BASE}

# Exact opencode-ai version (`npm view opencode-ai versions`); a dist-tag
# would float.
ARG OPENCODE_VERSION=1.19.5

# The official npm package (not the curl installer): it ships per-platform
# binaries as optionalDependencies and a postinstall that links the right one.
RUN npm install --global --no-fund --no-audit --no-update-notifier "opencode-ai@${OPENCODE_VERSION}" \
    && opencode --version

# State directories must exist in the image owned by the agent user: a fresh
# named volume mounted on a path the image doesn't own comes up root-owned, and
# opencode then dies with
# "PermissionDenied: FileSystem.open (.../log/opencode.log)". install -d sets
# the ownership explicitly (COPY would create missing parents as root), and
# the recursive pass covers what `opencode --version` created as root above.
RUN install -d -o 1000 -g 1000 \
        "/home/agent/.config/opencode" \
        "/home/agent/.local/share/opencode" \
        "/home/agent/.local/state/opencode" \
        "/home/agent/.cache/opencode" \
    && chown -R 1000:1000 "/home/agent/.local" "/home/agent/.config" "/home/agent/.cache"

# NOTE: no `USER` switch. s6-overlay's /init is PID 1 as root and drops to the
# agent user per service (agent-base's services.d), so the image must stay root
# here.

# The base's entrypoint hands the container CMD to this command, so the compose
# `command:` supplies the subcommand and flags.
ENV AGENT_CMD=opencode

EXPOSE 4096
