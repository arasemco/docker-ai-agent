# Troubleshooting

## The UI does not answer

1. Is the container running? `docker compose ps` (or `make ps`).
2. What does it say? `make logs` — the `[agent]` and s6 lines show
   what was executed and whether it exited.
3. Is the port taken? Publishing `4096` fails if another stack already uses it;
   set `OPENCODE_PORT` to a free one.
4. Is it bound where you look? The default binding is `127.0.0.1`; from another
   machine it is invisible until `OPENCODE_BIND_IP=0.0.0.0`.

`make smoke` reports the HTTP status, both s6 services and the opencode version
in one go.

## HTTP 401

Expected: the UI is protected by basic auth. Use
`OPENCODE_SERVER_PASSWORD` from `.env` (default `changeme123`). A `401` from
`curl` is also how the smoke test proves the server is alive.

## The container is unhealthy

The healthcheck proves the `opencode` process exists and warns when the inner
Docker daemon is down. Unhealthy therefore means the CLI exited: read
`make logs`, and check `/run/agent/exit-code` inside the container for its
status.

## The inner Docker daemon is not running

`make smoke` prints the daemon version, or `SKIP` when it is not responding.
The daemon log is `/home/agent/.docker/dockerd.log` inside the container. Two
causes:

- the container was started without the `daemon` anchor (no `/dev/fuse`, no
  seccomp exceptions) — use `make up` or `scripts/compose.sh`;
- the base image predates agent-base 1.4.0, which adapts `/etc/subuid` when the
  container itself runs under a rootless daemon. Bump `AGENT_BASE`.

## My configuration changes have no effect

`opencode.jsonc` is read from `/home/agent/.config/opencode/` inside the
container. If `OPENCODE_CONFIG_HOST` points at a host directory, edit that
directory, not the file in this repository: the image no longer seeds a config.
`examples/config/opencode.jsonc` is a template to copy.

## Exit status looks wrong

The container's exit status is s6's, not the CLI's. The CLI's own status is in
`/run/agent/exit-code`, and is logged by the agent service when it exits.
