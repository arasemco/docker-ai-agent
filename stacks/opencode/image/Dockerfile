# syntax=docker/dockerfile:1
# =============================================================================
# opencode — the OpenCode CLI/Web UI on top of agent-base
# =============================================================================
# agent-base provides the sandbox, the agent user, s6, the rootless daemon and
# the launch/health/state contracts. This image adds only OpenCode, its launch
# line, its state manifest and its health fragment.
# =============================================================================
ARG AGENT_BASE
FROM ${AGENT_BASE} AS opencode
ARG AGENT_CONTRACT=2
ARG OPENCODE_VERSION

RUN npm install --global --no-fund --no-audit --no-update-notifier "opencode-ai@${OPENCODE_VERSION}" \
    && opencode --version \
    && install -d -o 1000 -g 1000 \
        "/home/agent/.config/opencode" \
        "/home/agent/.local/share/opencode" \
        "/home/agent/.local/state/opencode" \
        "/home/agent/.cache/opencode" \
    && chown -R 1000:1000 "/home/agent/.config" "/home/agent/.local" "/home/agent/.cache"

COPY --chmod=755 agent-launch.d/agent.sh /etc/agent-launch.d/agent.sh
COPY --chmod=644 state.d/ /etc/agent-state.d/
COPY --chmod=755 health.d/ /etc/agent-healthcheck.d/

EXPOSE 4096

FROM opencode AS test
ARG AGENT_CONTRACT
RUN /usr/local/lib/agent-base/contract.sh \
    && [ "$(cat /etc/agent-base/CONTRACT)" = "${AGENT_CONTRACT}" ] \
    && opencode --version
