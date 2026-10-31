# Working on this repository

Orientation for a coding agent (or a human in a hurry).

## What this repository is

One image: the OpenCode CLI and Web UI installed on top of
[agent-base](../../agent-base/README.md). Everything shared — Debian base, agent
user, s6 services, rootless Docker daemon, toolchain, entrypoint, healthcheck —
lives in agent-base. This repository adds OpenCode and nothing else.

## Map

| Path | Contents | Notes |
|---|---|---|
| `image/Dockerfile` | `FROM agent-base`, `opencode-ai` from npm, state dirs, `AGENT_CMD` | the only place the CLI is installed |
| `docker-compose.yml` | port, credentials, state volumes | no devices, proxy or limits |
| `scripts/compose.sh` | wrapper over agent-base's fragment assembler | fixes service name and paths |
| `scripts/bake.sh` | copied from agent-base | keep byte-identical to avoid drift |
| `scripts/smoke.sh` | runtime check of the stack | UI, services, daemon, health |
| `docker-bake.hcl` | targets, pins, OCI labels | neutral defaults |
| `examples/` | config, env and compose starting points | not used by the build |
| `docs/` | user documentation | |

## Invariants

1. **No sandbox settings in this repository.** Devices, seccomp, proxy, limits,
   mounts and skills come from agent-base fragments. If a change needs one of
   them, select the fragment with `WITH`, do not copy it here.
2. **`AGENT_BASE` stays pinned to a version tag**, never `:latest`. Bump it
   deliberately — see the `bump-agent-base` skill.
3. **No `USER 1000:1000` in the Dockerfile.** `/init` must be PID 1 as root.
4. **State directories are created in the image, owned by uid 1000.** A named
   volume mounted on a path the image does not own comes up root-owned and the
   CLI fails to write its log.
5. **No provider configuration baked in.** Providers are deployment-specific;
   `examples/config/` shows a template.
6. **Comments describe behaviour.** No history, no decision narrative.

## Recipes

**Bump the CLI.** `OPENCODE_VERSION` in `image/Dockerfile`, `docker-compose.yml`,
`docker-bake.hcl`, `.env.example` (and `.env`), then `make build` and
`make smoke`.

**Bump agent-base.** See the `bump-agent-base` skill; six files carry the pin.

**Add an environment variable.** Compose `environment:` entry, `.env.example`
row, and a line in `docs/configuration.md`. If it is a sandbox setting, it
belongs in agent-base instead.

**Add a hook.** Copy `*.sh` into the image at `/etc/agent-entrypoint.d/`; the
hook is sourced as the agent user before the CLI starts and may rewrite `$@`.

## Checks before committing

```bash
shellcheck scripts/*.sh
scripts/compose.sh -- config >/dev/null
make build          # image builds against the pinned AGENT_BASE
make up && make smoke
```

`make smoke` reports `SKIP` for the inner daemon only if it is genuinely down;
on agent-base 1.4.0 or newer it starts even inside a rootless host daemon.
