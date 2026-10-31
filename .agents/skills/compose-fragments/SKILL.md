---
name: compose-fragments
description: Add, change or combine the compose fragments in compose/ — one file per concern, assembled by scripts/compose.sh or included by the root docker-compose.yml. Use when a task changes how a stack is put together, adds a new opt-in concern, or wires a child stack.
metadata:
  area: compose
  files: compose/, docker-compose.yml, scripts/compose.sh
---

# Compose fragments

## Model

Each file in `compose/` owns exactly one concern and keys the canonical service
name `agent-base`. A composing file chooses which fragments to merge.

| Fragment | Owns |
|---|---|
| `base.yml` | service skeleton, `AGENT_*` toggles |
| `daemon.yml` | devices, seccomp exceptions, `agent-docker` volume |
| `image.yml` | build of `image/` (name, context, args; no command, no mounts) |
| `harness.yml` | keep-alive command used by tests only |
| `proxy.yml` | proxy variables with the `PROXY` fallback |
| `limits.yml` | `AGENT_CPUS` / `AGENT_MEMORY` |
| `mounts.yml` | host bind for the workspace |

## Adding a fragment

1. Create `compose/<concern>.yml`, keyed `agent-base`, with a header that says
   what the one concern is and why the settings exist.
2. Declare any volume the fragment mounts in the same file (`volumes:` at the
   end). Otherwise including it fails with `refers to undefined volume`.
3. Register it in `scripts/compose.sh`'s ordered list
   (`base daemon proxy limits mounts`) so selection is order-independent.
4. Document it in the fragment table in `README.md` and in
   `docs/compose.md`; if it reads variables, add them to
   `docs/configuration.md`.

## Combining

```bash
docker compose up -d                      # root file: include base + daemon + image
docker compose --profile opencode up -d
make up WITH=daemon,limits,mounts
```

`scripts/compose.sh` also merges a gitignored `compose/local.yml`, and rewrites
the service key when `--service` names a child stack.

## Rules that are easy to break

- **One concern per file.** `image.yml` must not set `command` or mounts;
  `daemon.yml` must not carry proxy variables.
- **No deployment values in the core.** A fragment may read an environment
  variable, but must not default to a host, IP or personal path.
- **Relative paths.** A fragment's `build.context` is resolved against the
  fragment's directory for `include:`/`extends`, so `compose/image.yml` uses
  `../image`. Child stacks use `./image` and rely on the assembler anchoring
  `--project-directory` to their stack file.
- **`extends` cannot stack fragments.** Compose accepts one `extends` per
  service; this is why the assembler exists.

## Verify

```bash
docker compose config >/dev/null
scripts/compose.sh --with daemon,proxy,limits,mounts --file compose/image.yml -- config >/dev/null
scripts/compose.sh --service probe --file compose/image.yml -- config | grep 'probe:'
```

## References

- [docs/compose.md](../../../docs/compose.md)
- [docs/configuration.md](../../../docs/configuration.md)
