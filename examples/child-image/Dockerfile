# syntax=docker/dockerfile:1
# =============================================================================
# Example: the smallest useful child image on top of agent-base
# =============================================================================
# agent-base provides the sandbox, the agent user, s6, the rootless daemon and
# the launch/health/state contracts. A child adds only its CLI and its contract
# files.
#
# Copy this directory somewhere and adjust:
#   docker compose -f docker-compose.yml up -d --build
# =============================================================================
ARG AGENT_BASE=agent-base:2.0.0
FROM ${AGENT_BASE}
ARG AGENT_CONTRACT=2

# Pin the CLI exactly; replace with the package and channel the CLI uses.
ARG CLI_VERSION=1.0.0
RUN npm install --global --no-fund --no-audit --no-update-notifier "example-cli@${CLI_VERSION}" \
    && example-cli --version

# The contract files, not a replacement run script.
COPY agent-launch.d/agent.sh /etc/agent-launch.d/agent.sh
COPY state.d/ /etc/agent-state.d/
# Optional: COPY hooks/ /etc/agent-entrypoint.d/
# Optional: COPY health.d/ /etc/agent-healthcheck.d/

# NOTE: no `USER` switch. s6-overlay's /init is PID 1 as root and drops to the
# agent user per service; the CLI itself still runs unprivileged.
