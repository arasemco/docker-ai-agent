# Compose model

## Fragments

`compose/` holds one file per concern, each keyed to the canonical service name
`agent-base`:

| Fragment | Owns | Selected by |
|---|---|---|
| `base.yml` | service skeleton (`init`, tty, restart, hostname) and `AGENT_*` toggles | always |
| `daemon.yml` | `/dev/fuse`, `/dev/net/tun`, seccomp exceptions, `agent-docker` volume | `--with daemon` (default) |
| `image.yml` | build of `image/` (image name, build args, target) | the root file, `make` |
| `harness.yml` | the keep-alive command used by tests | `make`, `scripts/smoke.sh` |
| `proxy.yml` | proxy variables (`X` → lowercase `x` → `PROXY` → empty) | `--with proxy` |
| `limits.yml` | `AGENT_CPUS` / `AGENT_MEMORY` | `--with limits` |
| `mounts.yml` | host bind for the workspace (`AGENT_WORKSPACE_HOST`) | `--with mounts` |
| `skills.yml` | host bind for the global Agent Skills root (`AGENT_SKILLS_HOST`, read-only) | `--with skills` |

Each fragment declares the volume it mounts, so a composing file never has to
repeat volume declarations.

## Two ways to combine them

**Include (no script).** The root `docker-compose.yml` includes `base`, `daemon`
and `image`:

```bash
docker compose up -d --build
```

**Assembler (any combination).** `scripts/compose.sh` builds the `-f` list,
appends a gitignored `compose/local.yml`, and runs compose:

```bash
scripts/compose.sh --with daemon,proxy -- up -d
scripts/compose.sh --with daemon,limits,mounts --file compose/image.yml -- up -d
make up WITH=daemon,proxy          # same, via make
```

## Why an assembler exists

Compose merges files that name the **same service**, and it accepts only one
`extends` per service, so fragments cannot be stacked with `extends`. For a
child stack whose service is called something else (`opencode`, `myagent`), the
assembler rewrites the fragment's service key in a temporary copy before
merging. Child repositories wrap the script:

```bash
exec ../agent-base/scripts/compose.sh \
    --service myagent \
    --fragments ../agent-base/compose \
    --file docker-compose.yml "$@"
```

## Relative paths

Compose resolves relative paths against the project directory, which it infers
from the first file it is given. The assembler anchors `--project-directory` to
the directory of the `--file` stack, so:

- a child's `context: ./image` means *that child's* `image/`;
- this repo's `compose/image.yml` uses `context: ../image`, which resolves to
  the same place.

`include:` inside `docker-compose.yml` follows the included file's own directory,
which is why `compose/image.yml` is written with `../image`.

## Local overrides

`compose/local.yml` is gitignored and appended automatically by the assembler
when present. It is the place for per-host binds and tweaks; the root
`docker-compose.yml` is the portable default and should stay free of them.
`examples/compose/local.yml` is a starting point.
