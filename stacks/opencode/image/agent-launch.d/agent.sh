# OpenCode Web UI launch line. Sourced by agent-run as the agent user.
AGENT_LAUNCH=(opencode web --port "${OPENCODE_PORT:-4096}" --hostname 0.0.0.0)
