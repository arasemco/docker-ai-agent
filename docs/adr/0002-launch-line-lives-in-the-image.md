# 0002 — The launch line lives in the image

Status: accepted

Each stack ships `/etc/agent-launch.d/agent.sh`, a sourced file that sets
`AGENT_LAUNCH`. The base `services.d/agent/run` is fixed and never replaced, so
the dockerd wait, privilege drop, hooks and restart bookkeeping cannot be
bypassed. Compose carries no `command:`; a container `CMD` is not the launch
line.
