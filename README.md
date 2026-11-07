# ai/agent

One sandbox image (`base/`) and one module per agent CLI (`stacks/`). Each stack
is an independent image built `FROM` the base; compose runs the published image
references, and `tooling/` owns build, checks and release.

| Stack | What it runs |
|---|---|
| [`stacks/opencode`](stacks/opencode/README.md) | OpenCode CLI and Web UI on a published loopback port |
| [`stacks/dsh`](stacks/dsh/README.md) | DeepSeek Harness Web UI, loopback-only through host networking |
| [`stacks/claude`](stacks/claude/README.md) | Claude Code CLI, run from an exec session |
| `base` | sandbox only: no agent CLI |

## Quick start

```bash
cp .env.example .env
make up PROFILE=opencode    # builds the base variant + stack, then starts it
make up PROFILE=dsh
make up PROFILE=claude      # then: make exec PROFILE=claude
```

`make up` builds through `tooling/bake.sh` and runs compose with the exported
image references. Compose itself carries no `build:` keys. A host overlay is
optional:

```bash
make up PROFILE=dsh LOCAL_COMPOSE=docker-compose.local.yml
```

## Module tree

```
versions.env              every pin, version and image reference
base/                     sandbox image, contract, compose and bake fragments
stacks/<id>/              stack.yaml, image/, compose.yml, bake.hcl, test/, docs/
compose/common.yml        shared sandbox service
docker-compose.yml        include index for the module fragments
tooling/                  build, check, smoke, generate, release
tests/                    unit + contract checks; integration/e2e homes
config/knobs.env          deployment knob registry
docs/                     user documentation; docs/reference is generated
examples/                 deployment starting points, never used by the build
```

## Commands

```bash
make check                  # hermetic contract checks
make build PROFILE=opencode # base + one stack
make build-all              # base variants + every stack
make up PROFILE=dsh         # build and run
make smoke PROFILE=dsh      # probe the running stack
make generate               # regenerate docs/reference and .env.example
make test                   # base test stage
tooling/bake.sh <target>    # the build entry point
```

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | reading order and module map |
| [docs/explanation/architecture.md](docs/explanation/architecture.md) | base image, boot sequence, launch/health/state contracts |
| [docs/reference/compose-model.md](docs/reference/compose-model.md) | common service, module fragments, profiles, host overlay |
| [docs/reference/configuration.md](docs/reference/configuration.md) | environment, generated reference, hooks |
| [docs/how-to/build-and-release.md](docs/how-to/build-and-release.md) | versions, targets, release, CI |
| [docs/how-to/troubleshooting.md](docs/how-to/troubleshooting.md) | known failure modes |
| [docs/adr/](docs/adr/) | architecture decisions |

Working on the repository? Start at [.agents/README.md](.agents/README.md).

## License

MIT — see [LICENSE](LICENSE).
