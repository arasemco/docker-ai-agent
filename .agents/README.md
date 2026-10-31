# Working on this repository

Orientation for a coding agent (or a human in a hurry).

## What this repository is

One image: the DeepSeek Harness (`dsh`) Web UI installed on top of
[agent-base](../../agent-base/README.md). Everything shared — Debian base, agent
user, s6 services, rootless Docker daemon, toolchain, entrypoint, hooks and
healthcheck — lives in agent-base, except two things this repository must supply
itself: Node 22 (the base has 18.20, dsh needs ≥22.19) and dsh's own
healthcheck.

## Map

| Path | Contents | Notes |
|---|---|---|
| `image/Dockerfile` | `agent-base` base, Node compiled from source, `dsh` from npm, hook, healthcheck | three stages: `node-build`, `runtime`, `test` |
| `image/healthcheck.mjs` | signs a browser-session cookie, requires HTTP 200 | copied to `/usr/local/lib/` |
| `image/hooks/20-dsh-flags.sh` | turns `DSH_*` into `dsh web` options | sourced by agent-base's `agent-run` |
| `docker-compose.yml` | host networking, credentials, `DSH_*` | no devices, proxy or limits |
| `scripts/compose.sh` | wrapper over agent-base's fragment assembler | fixes service name and paths |
| `scripts/bake.sh` | copied from agent-base | keep byte-identical to avoid drift |
| `scripts/smoke.sh` | runtime check of the stack | runs the real healthcheck |
| `docker-bake.hcl` | targets (`dsh`, `dsh-dev`, `test`), pins, labels | `test` needs credentials |
| `docs/`, `examples/` | documentation and copy-paste material | |

## Invariants

1. **The runtime image stays on agent-base.** Node is compiled from source in a
   stage that also starts from agent-base; do not introduce another base image or
   a third-party apt repository.
2. **Node stays pinned to 22.23.4 + sha256.** `NODE_VERSION` and `NODE_SHA256`
   change together, in `image/Dockerfile` and `docker-bake.hcl`.
3. **No sandbox settings here.** Devices, seccomp, proxy, limits, mounts and
   skills come from agent-base fragments; select them with `WITH`.
4. **`AGENT_BASE` stays pinned to a version tag**, bumped deliberately (see the
   `bump-agent-base` skill).
5. **Host networking is a requirement, not a preference.** dsh binds loopback
   and refuses wildcards; `network_mode: host` is what makes the UI reachable.
6. **`DEEPSEEK_API_KEY` is never put in the environment.** The file path is what
   the test stage exists to prove.
7. **No `USER 1000:1000`.** `/init` must be PID 1 as root.
8. **Comments describe behaviour**, not history.

## Recipes

**Bump dsh.** `DSH_VERSION` in `image/Dockerfile`, `docker-compose.yml`,
`docker-bake.hcl`, `.env.example`, then `make build` and `make smoke`.

**Bump Node.** New `NODE_VERSION` and the matching `NODE_SHA256` from that
release's `SHASUMS256.txt`, in both the Dockerfile and the bake file. Rebuild
(compilation is cached by the `ADD` checksum).

**Change the flag translation.** `image/hooks/20-dsh-flags.sh`; it runs as the
agent user before the CLI starts and may rewrite `$@`. Anything not `web` must
pass through untouched.

**Change the healthcheck.** `image/healthcheck.mjs`. It must not require more
than the credentials file and the running server.

## Checks before committing

```bash
shellcheck scripts/*.sh image/hooks/*.sh
scripts/compose.sh -- config >/dev/null
make build          # cold builds compile Node; later ones are cached
make up && make smoke
```

`make test` additionally spends a real API call and a headless dsh run; it needs
a credentials file (see `DSH_CREDENTIALS` in the makefile).
