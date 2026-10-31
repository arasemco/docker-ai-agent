# syntax=docker/dockerfile:1
# =============================================================================
# Example: the smallest useful child image on top of agent-base
# =============================================================================
# Everything shared — Debian base, the agent user, s6 supervision, the rootless
# Docker daemon, the toolchain, hooks and healthcheck — comes from agent-base.
# A child adds only its CLI, its config and its default launch line.
#
# Copy this directory somewhere and adjust:
#   docker compose build && docker compose up -d
# =============================================================================

ARG AGENT_BASE=agent-base:1.5.0
FROM ${AGENT_BASE}

# Pin the CLI exactly; a dist-tag would float. Replace this with the package
# name and channel the real CLI uses: npm, PyPI, or a release binary.
ARG CLI_VERSION=1.0.0
RUN npm install --global --no-fund --no-audit --no-update-notifier "example-cli@${CLI_VERSION}" \
    && example-cli --version

# State directories must exist in the image owned by the agent user: a fresh
# named volume mounted on a path the image doesn't own comes up root-owned.
RUN install -d -o 1000 -g 1000 "/home/agent/.config/example-cli" \
    && chown -R 1000:1000 "/home/agent/.config"

# Optional: drop extra agent hooks here (sourced before the CLI starts).
# COPY hooks/ /etc/agent-entrypoint.d/

# The s6 agent service's launch line: the executable, then any arguments. It
# replaces the base image's run script, so the image — not the compose file or a
# container command — decides what runs. See the real stacks:
# stacks/opencode/image/services.d/agent/run,
# stacks/deepseek-harness/image/services.d/agent/run.
COPY services.d/agent/run /etc/services.d/agent/run

# NOTE: no `USER` switch. s6-overlay's /init is PID 1 as root and drops to the
# agent user per service; the CLI itself still runs unprivileged.
