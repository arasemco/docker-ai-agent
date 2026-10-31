---
name: run-and-debug
description: Run agent-base in a container and diagnose misbehaviour — the inner Docker daemon not starting, workspace ownership errors, the container exiting immediately, unhealthy status, or unexpected exit codes. Use when a stack starts but does not work as expected.
metadata:
  area: runtime
  files: image/rootfs/etc/services.d/, image/rootfs/etc/cont-init.d/, scripts/smoke.sh
---

# Run and debug

## Run

```bash
make up PROFILE=opencode                          # or PROFILE=dsh
docker compose --profile opencode up -d --build   # same, without make
docker compose --profile base up -d               # sandbox only
docker compose --profile opencode exec --user 1000 opencode bash   # agent's shell
```

## Read the right output first

| Question | Where |
|---|---|
| did the daemon start, and why not | `docker compose exec agent-base cat /home/agent/.docker/dockerd.log` |
| what are the services doing | `docker compose exec agent-base sh -c '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'` |
| how did the CLI end | `/run/agent/exit-code` and the container log (`[agent]` lines) |
| is the image healthy overall | `scripts/smoke.sh` |

## Failure patterns

**`newuidmap: write to uid_map failed: Operation not permitted`** — the
container's `/etc/subuid` names ids its parent namespace cannot reach.
`cont-init.d/10-prepare` rewrites the ranges when it detects this; verify the
`rewrote /etc/subuid ...` line in the container log and that
`AGENT_SUBID_REMAP` is not `0`.

**`dockerd` prints its usage and exits** — the launcher received a stray
`dockerd` word. `dockerd-rootless.sh` (Debian) takes dockerd flags directly,
`dockerd-entrypoint.sh` (Alpine) expects the command first; the service picks
the right form per launcher.

**`dockerd exited during startup` with mount errors** — the container lacks
`seccomp:unconfined`, `systempaths=unconfined`, `/dev/fuse` or `/dev/net/tun`.
Every compose service merges the `x-sandbox` anchor; a bare `docker run` must
pass these settings itself.

**`ERROR: /home/agent/workspace is not writable`** — a bind source that uid 1000
cannot write: a missing directory Docker created root-owned, or a rootless host
where bind mounts appear root-owned inside. Create the directory owned by uid
1000 on the host, use a named volume, or run the outer daemon rootful.

**Container exits immediately** — the launch line in `image/services.d/agent/run`
returned. The base image launches `agent-idle` and stays up; a stack launches
its CLI, so its exit is the CLI's. A container `CMD` is run by s6 as a one-off
foreground command after services start, not as the launch line.

**Unhealthy but the CLI answers** — `AGENT_HEALTHCHECK=auto` only warns about a
dead daemon; a real failure means the s6 `agent` service is down.

**Exit status confusion** — the container exits with s6's status, not the CLI's.
The CLI's own status is in `/run/agent/exit-code`.

## Verify a fix

```bash
scripts/smoke.sh                    # full runtime check
SMOKE_REQUIRE_DOCKER=1 make smoke   # fail instead of SKIP where the daemon must work
```

## References

- [docs/troubleshooting.md](../../../docs/troubleshooting.md)
- [docs/architecture.md](../../../docs/architecture.md)
