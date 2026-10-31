# Troubleshooting

## `docker` does not work inside the container

The daemon service logs why; read `/home/agent/.docker/dockerd.log`.

| Symptom in the log | Cause | Fix |
|---|---|---|
| `newuidmap: write to uid_map failed: Operation not permitted` | the host's own Docker daemon is rootless, so a second level of user namespaces is refused | run on a rootful host; there is no workaround inside the container |
| `failed to setup UID/GID map` / rootlesskit errors | the container lacks `seccomp:unconfined`, `systempaths=unconfined` or the devices | select the `daemon` fragment or add those settings |
| `permission denied` on `/dev/fuse` | `/dev/fuse` not passed through | add the device |

The agent still runs without the daemon; `AGENT_DOCKERD=0` makes that explicit
and silences the start attempt.

## `ERROR: /home/agent/workspace is not writable`

A bind-mounted host directory that uid 1000 cannot write. Two causes:

- the directory does not exist, and Docker created it root-owned;
- the host's Docker is rootless, which makes bind mounts appear root-owned
  *inside* the container.

Fix: create the directory on the host owned by uid 1000 before starting, use a
named volume instead, or run the outer daemon rootful. `cont-init` chowns the
mount point when it can.

## The container exits immediately

The `agent` service runs `$AGENT_CMD`; with no command it runs a shell that
exits without a TTY. A stack that should stay up sets a command — the root
`docker-compose.yml` and `compose/harness.yml` use `bash -lc 'sleep infinity'`.

## The container is "unhealthy" but the CLI works

`AGENT_HEALTHCHECK=auto` only warns when the daemon is down; a persistent
unhealthy status means the CLI process is not running — check
`scripts/smoke.sh` output or `/run/agent/exit-code`.

## Port already in use

A stack publishing the same port as another container fails to start. Change
the published port in `.env` (`OPENCODE_PORT`-style variables in child stacks).

## `refers to undefined volume`

A fragment mounts a volume the composing project did not declare. Fragments
declare their own; a child stack must declare the volumes its own compose file
uses.

## Compose project name surprises

The project name defaults to the directory of the first compose file. The root
`docker-compose.yml` pins `name:`, and `compose/image.yml` pins it for script
mode, so both paths create `agent-base-<service>-1`. Override with
`COMPOSE_PROJECT_NAME` when running several stacks from one directory.
