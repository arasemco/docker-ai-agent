# Base launch line: the image carries no CLI, so the agent service supervises
# the idler. A stack image replaces this file with its own launch line:
#
#   AGENT_LAUNCH=(my-cli web --port 8080)
#
# Sourced by agent-run as the agent user, after the dockerd wait.
# shellcheck disable=SC2034  # consumed by agent-run, which sources this file
AGENT_LAUNCH=(/usr/local/bin/agent-idle)
