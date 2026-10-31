# Verification commands

Run from the repository root.

| Check | Command | Expected |
|---|---|---|
| Shell scripts | `shellcheck scripts/*.sh image/hooks/*.sh` | exit 0 |
| Compose config | `scripts/compose.sh -- config >/dev/null` | exit 0 |
| Image build | `make build` | `dsh:local`; node and npm report 22.x / 10.x |
| Runtime | `make up && make smoke` | healthcheck ok, both services up, `OK` |
| Healthcheck alone | `scripts/compose.sh -- exec --no-TTY dsh node /usr/local/lib/dsh-healthcheck.mjs` | exit 0 |
| CLI version | `scripts/compose.sh -- exec --no-TTY dsh dsh --version` | the pinned `DSH_VERSION` |
| Node version in image | `scripts/compose.sh -- exec --no-TTY dsh node --version` | `v22.23.4` |
| Inner daemon | `scripts/compose.sh -- exec --no-TTY dsh docker info --format '{{.ServerVersion}} {{.Driver}}'` | `29.8.1 fuse-overlayfs` |
| Services | `scripts/compose.sh -- exec --no-TTY dsh sh -c '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'` | both `up` |
| API key + headless run | `make test` | `test: API key valid`, `test: dsh headless answered: OK` |
| Base pin consistency | `grep -rn "agent-base:[0-9]" image/Dockerfile docker-compose.yml docker-bake.hcl .env.example` | one version, matching agent-base's `BASE_VERSION` |

## Reading failures

- `target stage "runtime" could not be found` — a stage lost its `AS runtime`
  name; compose and bake both build that stage.
- `pull access denied` for `agent-base:x.y.z` — that base tag is neither built
  locally nor pushed; build it in agent-base first.
- Healthcheck exits 1 with `no client-connection/browser-session secret yet` —
  the UI has not been signed in, so the file has no session secret.
- `dsh: command not found` — the npm install did not run or `/opt/node/bin` is
  not on PATH.
