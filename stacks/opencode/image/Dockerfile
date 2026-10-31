# syntax=docker/dockerfile:1
# =============================================================================
# opencode — the OpenCode CLI/Web UI on top of agent-base
# =============================================================================
# This image adds only OpenCode to the shared sandbox provided by agent-base:
# the Debian base, the agent user, s6 supervision, the rootless Docker daemon,
# the toolchain and the healthcheck all come from there.
#
# Contents:
#   * opencode-ai from npm, pinned to an exact version
#   * its state directories, owned by the agent user
#   * services.d/agent/run, the s6 service's launch line (`opencode web ...`)
#
# No provider configuration is baked in: which providers exist and where they
# run is deployment-specific. See ../examples/config/.
# =============================================================================

# The shared base, pinned to a tag so a rebuild is reproducible. Without a
# registry prefix this resolves to a locally built image; override AGENT_BASE to
# use a pushed one.
ARG AGENT_BASE=agent-base:1.5.0
FROM ${AGENT_BASE} AS opencode

# Exact opencode-ai version (`npm view opencode-ai versions`); a dist-tag would
# float.
ARG OPENCODE_VERSION=1.19.5

# The official npm package ships per-platform binaries as optionalDependencies
# and a postinstall that links the right one. Installed as root so it lands in
# /usr/local and is on the agent user's PATH.
RUN npm install --global --no-fund --no-audit --no-update-notifier "opencode-ai@${OPENCODE_VERSION}" \
    && opencode --version

# State directories must exist in the image owned by the agent user: a fresh
# named volume mounted on a path the image does not have comes up root-owned,
# and opencode then fails with
# "PermissionDenied: FileSystem.open (.../log/opencode.log)". install -d sets the
# ownership explicitly; the recursive pass covers what `opencode --version`
# created as root above.
RUN install -d -o 1000 -g 1000 \
        "/home/agent/.config/opencode" \
        "/home/agent/.local/share/opencode" \
        "/home/agent/.local/state/opencode" \
        "/home/agent/.cache/opencode" \
    && chown -R 1000:1000 "/home/agent/.local" "/home/agent/.config" "/home/agent/.cache"

# No USER switch: s6-overlay's /init is PID 1 as root and drops to the agent
# user per service. The CLI itself runs unprivileged.

# The stack's launch line lives in the image, not in the compose file: this
# replaces the base image's services.d/agent/run with `opencode web ...`.
COPY --chmod=755 services.d/agent/run /etc/services.d/agent/run

EXPOSE 4096
