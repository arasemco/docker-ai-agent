# Troubleshooting

## `docker` does not work inside the container

The daemon service logs why; read `/home/agent/.docker/dockerd.log`.

| Symptom in the log | Cause | Fix |
|---|---|---|
| `newuidmap: write to uid_map failed: Operation not permitted` | `/etc/subuid` names ids the parent namespace cannot reach — typical when the container itself runs under a rootless daemon | automatic: `cont-init.d/10-prepare` rewrites the ranges; `AGENT_SUBID_REMAP=0` disables that |
| `failed to setup UID/GID map` / rootlesskit errors | the container lacks `seccomp:unconfined`, `systempaths=unconfined` or the devices | use `make up` (every service merges `x-sandbox`), or add those settings |
| `permission denied` on `/dev/fuse` | `/dev/fuse` not passed through | add the device |

**Why the id ranges matter.** `newuidmap` resolves a user's subordinate ids by
name when rootlesskit builds its namespace. The image ships the layout a rootful
host uses (`agent:100000:65536`). A container created by a *rootless* host
daemon only reaches ids `0..65536`, so that range is refused with
`write to uid_map failed: Operation not permitted`.

`cont-init.d/10-prepare` detects the mismatch (the configured range is not fully
inside the container's id map) and rewrites `/etc/subuid` and `/etc/subgid` to
fit the reachable ids, skipping the agent account's own id because rootlesskit
maps that one to 0 inside its namespace. Nested daemons then start normally;
`AGENT_SUBID_REMAP=0` turns the rewrite off.

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

The `agent` service ran the image's launch line and it returned; when it exits
cleanly, the container stops. The base image's line is the idle helper, so it
stays up; a stack's line is its CLI (`opencode web`, `dsh web`), and a fast
crash there is a CLI problem, not a compose one. Check the `[agent]` log line
and, for a stack, `image/services.d/agent/run`. A container `CMD` is run by s6
as a one-off foreground command after the services start, so it cannot stand in
for the launch line.

## The container is "unhealthy" but the CLI works

`AGENT_HEALTHCHECK=auto` only warns when the daemon is down; a persistent
unhealthy status means the s6 `agent` service is down — check
`/command/s6-svstat /run/service/agent` and `/run/agent/exit-code`.

## Port already in use

A stack publishing the same port as another container fails to start. Change
the published port in `.env` (`OPENCODE_PORT`-style variables in child stacks).

## `refers to undefined volume`

An anchor mounts a volume that the project's top-level `volumes:` block does not
declare. A child stack must declare the volumes its own compose file uses.

## Compose project name surprises

The project name defaults to the directory of the first compose file. The root
`docker-compose.yml` pins `name: agent`, so containers are named
`agent-<service>-1` regardless of how compose is invoked. Override with
`COMPOSE_PROJECT_NAME` when running several stacks from one directory.
