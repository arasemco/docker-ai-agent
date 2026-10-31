# ai/agent

One base image and every agent stack that runs on it.

`ai/agent` packages the parts an AI coding-agent container needs — a glibc
distribution with Node, one unprivileged user, an s6-supervised rootless Docker
daemon, a development toolchain, hooks and a healthcheck — and then layers one
agent CLI per stack:

| Stack | What it runs |
|---|---|
| [`stacks/opencode`](stacks/opencode/README.md) | the OpenCode CLI and Web UI on a published loopback port |
| [`stacks/deepseek-harness`](stacks/deepseek-harness/README.md) | the DeepSeek Harness (`dsh`) Web UI, reachable through host networking |

The sandbox itself is the `all` profile: it also selects every stack, because a
stack service inherits the sandbox's profile through `extends`.

Nothing in the shared parts is host-, person- or project-specific: no registry,
no proxy, no host paths, no resource limits, no author metadata.

## Quick start

```bash
cp .env.example .env

make up PROFILE=opencode          # build base + opencode, start the Web UI
make up PROFILE=dsh               # build base + dsh, start its Web UI
```

Equivalently, without the makefile:

```bash
docker compose --profile opencode up -d --build
docker compose --profile opencode config  # see what a profile resolves to
```

Everything is optional: every value in `.env.example` is a default, and the
compose fragments read their knobs from the environment.

## How it is put together

```
image/                 the base image (Dockerfile + rootfs/)
compose/               one fragment per concern, included by docker-compose.yml
  base.yml             service skeleton + AGENT_* toggles
  daemon.yml           /dev/fuse, /dev/net/tun, seccomp exceptions, docker volume
  image.yml            build of image/ (the `base` profile)
  proxy.yml            outbound proxy pass-through (values from .env)
  limits.yml           CPU/memory from AGENT_CPUS / AGENT_MEMORY
  mounts.yml           workspace bind from AGENT_WORKSPACE_HOST
  skills.yml           shared Agent Skills root from AGENT_SKILLS_HOST
stacks/<name>/         image/ (Dockerfile + files), docs/, examples/
docker-compose.yml     includes the fragments and defines every stack service
docker-bake.hcl        targets: agent-base, opencode, dsh (+ dev and test)
scripts/               bake.sh (build + provenance), smoke.sh (runtime check)
docs/                  documentation for users
.agents/               orientation, checks and skills for coding agents
```

A stack service is only its own concerns — build, command, ports, credentials,
state volumes — because it `extends: agent-base` and inherits the whole sandbox:

```yaml
opencode:
  extends:
    service: agent-base
  profiles: ["opencode"]
  build: { context: ./stacks/opencode/image, args: { AGENT_BASE: agent-base:1.4.1 } }
  command: ["web", "--port", "4096", "--hostname", "0.0.0.0"]
```

## Building

```bash
make build                    # base image, then the PROFILE stack
make build-all                # base image, then every stack
make test                     # base test stage: shellcheck + tool matrix
make test-dsh                 # dsh test stage: real API key + headless run
scripts/bake.sh --push        # publish (registry derived from the git remote)
```

The base image is built first and the stacks build `FROM` it, so a single
`make build-all` produces a consistent set under the same tag.

## Documentation

| Document | Contents |
|---|---|
| [docs/index.md](docs/index.md) | overview and reading order |
| [docs/architecture.md](docs/architecture.md) | image contents, boot sequence, services, state |
| [docs/compose.md](docs/compose.md) | fragments, profiles, stack services |
| [docs/configuration.md](docs/configuration.md) | variables, volumes, hooks, healthcheck |
| [docs/build.md](docs/build.md) | targets, pins, provenance, publishing, CI |
| [docs/troubleshooting.md](docs/troubleshooting.md) | known failure modes |
| [stacks/opencode/docs/](stacks/opencode/docs/index.md) | OpenCode-specific configuration and troubleshooting |
| [stacks/deepseek-harness/docs/](stacks/deepseek-harness/docs/index.md) | dsh-specific configuration and troubleshooting |
| [.agents/README.md](.agents/README.md) | working on this repository |

## License

MIT — see [LICENSE](LICENSE).
