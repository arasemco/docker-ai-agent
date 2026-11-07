# 0004 — Nested rootless daemon and sub-id remap

Status: accepted

The container runs a rootless Docker daemon under s6. On hosts whose own Docker
is rootless, the default subordinate id range is unreachable; `20-subid` rewrites
`/etc/subuid` and `/etc/subgid` into ids the container can map. A missing daemon
degrades the agent, it does not stop it: the healthcheck warns, and
`AGENT_DOCKERD=0` makes the choice explicit.
