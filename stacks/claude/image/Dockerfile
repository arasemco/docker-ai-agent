# syntax=docker/dockerfile:1
# =============================================================================
# claude — Claude Code on top of agent-base (Node 22 variant)
# =============================================================================
# agent-base-node22 supplies Node 22; this image adds Claude Code and keeps the
# base idler as the launch line because Claude Code is an interactive TUI.
# =============================================================================
ARG AGENT_BASE
FROM ${AGENT_BASE} AS claude
ARG AGENT_CONTRACT=2
ARG CLAUDE_VERSION

RUN npm install --global --no-fund --no-audit --no-update-notifier "@anthropic-ai/claude-code@${CLAUDE_VERSION}" \
    && claude --version

RUN install -d -o 1000 -g 1000 -m 700 "/home/agent/.claude" \
    && chown -R 1000:1000 "/home/agent/.claude"
ENV CLAUDE_CONFIG_DIR=/home/agent/.claude

COPY --chmod=755 agent-launch.d/agent.sh /etc/agent-launch.d/agent.sh
COPY --chmod=644 state.d/ /etc/agent-state.d/

FROM claude AS test
ARG AGENT_CONTRACT
RUN /usr/local/lib/agent-base/contract.sh \
    && [ "$(cat /etc/agent-base/CONTRACT)" = "${AGENT_CONTRACT}" ] \
    && claude --version
