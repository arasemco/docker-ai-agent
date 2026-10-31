# opencode container

Runs the OpenCode Web UI in a sandbox built on
[agent-base](../agent-base/README.md): an inner rootless Docker daemon,
persistent state, and the same toolchain and proxy setup as the sibling
`claude-code` and `deepseek-harness` stacks.

This image contains only OpenCode: the shared parts (Debian 12, Node/npm from
apt, the `agent` user, rootless dockerd bootstrap, dev toolchain, entrypoint and
healthcheck) come from `git.omesa.net/asemo/agent-base`.

## Quick start

```bash
cp .env.example .env
# edit .env as needed (especially OPENCODE_SERVER_PASSWORD)
docker compose up -d --build
```

Open http://127.0.0.1:4096 — the UI is published on loopback by default because
the password has a weak fallback. Set `OPENCODE_BIND_IP=0.0.0.0` to expose it on
the LAN, and set a real password first.

## How it is put together

| Piece | Where it comes from |
|---|---|
| base image (Debian, apt Node/npm, agent user, dockerd, toolchain) | `AGENT_BASE` build arg, default `agent-base:1.0.0` |
| OpenCode itself | `npm install -g opencode-ai@${OPENCODE_VERSION}` in the Dockerfile |
| sandbox settings (devices, seccomp, limits, proxy, Projects mount) | `../agent-base/compose.base.yml` via `extends` |
| entrypoint / services / healthcheck | `agent-entrypoint` (stashes CMD, execs s6 `/init`), the `dockerd` + `agent` services and `agent-healthcheck` from the base |
| provider config | `opencode.jsonc`, seeded into the config volume on first run |

The agent CLI and the Docker daemon both run as `agent` (uid 1000), so all
state lives under `/home/agent`:

- `/home/agent/.config/opencode` — providers/models (volume `opencode-config`)
- `/home/agent/.local/share/opencode` — `auth.json`, session DB, snapshots (`opencode-data`)
- `/home/agent/.local/state/opencode` — XDG state (`opencode-state`)
- `/home/agent/Projects` — working directory (`${HOME}/Projects` on the host)
- `/home/agent/stacks` — read-only, except `000-templates`

Migrating from the previous Alpine image: the account is now `agent` instead of
`opencode`, but it is still uid/gid 1000 and the volumes keep their names
(`opencode-config`, `opencode-data`, `opencode-state`), so existing state is
reused as-is. Only config values that hardcode `/home/opencode/...` need
updating to `/home/agent/...`.

## Configuration

- Provider config: `opencode.jsonc` (seeded into the config volume on first run).
- Environment variables: see `.env.example`.
- Sandbox: `AGENT_DOCKERD=0` skips the inner daemon; `AGENT_*` variables are
  documented in [agent-base's README](../agent-base/README.md#contract).
- Proxy: set `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` in `.env`; a value left
  empty disables that proxy for the container.

## Smoke test

```bash
./scripts/smoke.sh
```

## Rebuild after changes

```bash
docker compose up -d --build
```

## Notes

- The inner Docker daemon needs `seccomp:unconfined`, `systempaths=unconfined`,
  `/dev/fuse` and `/dev/net/tun`; `compose.base.yml` sets them. On a host whose
  own Docker is rootless the nested daemon cannot start — the UI still works,
  and the entrypoint logs why (see agent-base's README).
- `opencode --version` is checked at build time and by the base healthcheck
  (`AGENT_CMD` alive); the image does not probe the HTTP port, because a
  password-protected UI answers 401 to a bare request.
- `docker exec` into this container lands as **root** (s6-overlay's PID 1); the
  CLI itself runs as `agent`. Use `docker compose exec --user 1000 opencode bash`
  for a shell with the agent's identity and environment.
