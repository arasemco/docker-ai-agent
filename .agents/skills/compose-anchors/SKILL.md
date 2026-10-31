---
name: compose-anchors
description: Add or change the shared compose anchors in docker-compose.yml (sandbox, environment, volumes) and the per-stack services that merge them. Use when a task changes how a stack is put together, adds a shared concern, or adds a new stack.
metadata:
  area: compose
  files: docker-compose.yml, makefile, scripts/smoke.sh
---

# Compose anchors

## Model

Each file in `compose/` owns exactly one concern and keys the canonical service
name `agent-base`. A composing file chooses which anchors to merge.

| Anchor | Owns |
|---|---|
| `base.yml` | service skeleton, `AGENT_*` toggles |
| `daemon.yml` | devices, seccomp exceptions, `agent-docker` volume |
| `image.yml` | build of `image/` (name, context, args; no command, no mounts) |
| `harness.yml` | keep-alive command used by tests only |
| `proxy.yml` | proxy variables with the `PROXY` fallback |
| `limits.yml` | `AGENT_CPUS` / `AGENT_MEMORY` |
| `mounts.yml` | host bind for the workspace |

## Adding a anchor

1. Create `compose/<concern>.yml`, keyed `agent-base`, with a header that says
   what the one concern is and why the settings exist.
2. Declare any volume the anchor mounts in the same file (`volumes:` at the
   end). Otherwise including it fails with `refers to undefined volume`.
3. Register it in `scripts/compose.sh`'s ordered list
   (`base daemon proxy limits mounts`) so selection is order-independent.
4. Document it in the anchor table in `README.md` and in
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
- **No deployment values in the core.** A anchor may read an environment
  variable, but must not default to a host, IP or personal path.
- **Relative paths.** A anchor's `build.context` is resolved against the
  anchor's directory for `include:`/`extends`, so the `agent-base` service uses
  `../image`. Child stacks use `./image` and rely on the assembler anchoring
  `--project-directory` to their stack file.
- **`extends` cannot stack anchors.** Compose accepts one `extends` per
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
