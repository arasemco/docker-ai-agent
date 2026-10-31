# Verification commands

Run from the repository root.

| Check | Command | Expected |
|---|---|---|
| Shell scripts | `shellcheck scripts/*.sh` | exit 0 |
| Compose config | `scripts/compose.sh -- config >/dev/null` | exit 0 |
| Fragment selection | `WITH=daemon,proxy,limits,mounts,skills scripts/compose.sh -- config >/dev/null` | exit 0 |
| Image build | `make build` | `opencode:local` tagged |
| Runtime | `make up && make smoke` | `OK (HTTP 401, health healthy)` |
| CLI version | `scripts/compose.sh -- exec --no-TTY opencode opencode --version` | `1.19.5` |
| Inner daemon | `scripts/compose.sh -- exec --no-TTY opencode docker info --format '{{.ServerVersion}} {{.Driver}}'` | `29.8.1 fuse-overlayfs` |
| Services | `scripts/compose.sh -- exec --no-TTY opencode sh -c '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'` | both `up` |
| Base pin consistency | `grep -rn "agent-base:[0-9]" image/Dockerfile docker-compose.yml docker-bake.hcl .env.example` | one version, matching `BASE_VERSION` in agent-base |

## Reading failures

- `PermissionDenied: FileSystem.open (.../log/opencode.log)` — the data volume is
  root-owned; the image must create the directory owned by uid 1000.
- `pull access denied` for `agent-base:x.y.z` — that base tag is not built
  locally and not pushed; build or push it in agent-base first.
- `service "opencode" is not running` from smoke — start with `make up`; smoke
  checks a running stack, it does not start one.
