# agent-base documentation

`agent-base` is a container image for AI coding-agent CLIs: a Debian sandbox with
an unprivileged user, a rootless Docker daemon under s6 supervision, and the
toolchain agents expect. It ships no CLI; the stack modules add one each.

## Reading order

| Document | What it answers |
|---|---|
| [explanation/architecture.md](explanation/architecture.md) | What is inside the base image? How does it boot? Launch, health, state? |
| [reference/compose-model.md](reference/compose-model.md) | How do the common service, module fragments, profiles and the host overlay fit? |
| [reference/configuration.md](reference/configuration.md) | Every environment variable, volume, path and hook. |
| [reference/environment.md](reference/environment.md) | Generated variable reference from `config/knobs.env`. |
| [reference/versions.md](reference/versions.md) | Generated pin matrix from `versions.env`. |
| [reference/stacks.md](reference/stacks.md) | Generated stack index from `stacks/*/stack.yaml`. |
| [how-to/build-and-release.md](how-to/build-and-release.md) | Building, versions, release gates and CI. |
| [how-to/troubleshooting.md](how-to/troubleshooting.md) | The failures worth knowing before they happen. |
| [adr/](adr/) | Decisions: module tree, launch line, common service, sub-ids, host overlay, claude. |

Working on the repository itself? Start at [`.agents/README.md`](../.agents/README.md).

## Stack modules

| Stack | Documentation |
|---|---|
| OpenCode | [stacks/opencode/docs/index.md](../stacks/opencode/docs/index.md) |
| DeepSeek Harness | [stacks/dsh/docs/index.md](../stacks/dsh/docs/index.md) |
| Claude Code | [stacks/claude/docs/index.md](../stacks/claude/docs/index.md) |

## The one-paragraph version

`base/Dockerfile` builds Debian 12 with Node/npm, an `agent:1000` user, the
rootless Docker daemon, a toolchain and s6. s6 runs two longruns: `dockerd` and
`agent`; the agent longrun sources `/etc/agent-launch.d/agent.sh` (shipped by the
stack), then hooks, and execs the CLI. Stack health/state fragments extend the
same contract. `tooling/bake.sh` builds every image from `versions.env`; compose
runs the exported image references, with module fragments included by
`docker-compose.yml`.

## Conventions

- **Base** — `base/`: the sandbox image and its contract. Generic, host-free.
- **Stack module** — `stacks/<id>/`: one CLI, its launch line, state, health,
  compose/bake fragments, probe and docs.
- **Common service** — `compose/common.yml`: profile-less, image-less,
  build-less; every module fragment extends it.
- **Host overlay** — `docker-compose.local.yml`: gitignored host values, passed
  with `LOCAL_COMPOSE` or `-f`.
- **Agent user** — `agent`, uid/gid 1000; the image ABI, not a deployment knob.

## Where each fact is owned

| Fact | Canonical home | Derived or checked |
|---|---|---|
| pins and versions | `versions.env` | `docs/reference/versions.md`, bake tags — generated |
| deployment knobs | `config/knobs.env` | `.env.example`, `docs/reference/environment.md` — generated |
| stack identity and metadata | `stacks/<id>/stack.yaml` | `docs/reference/stacks.md` — generated |
| launch line | `stacks/<id>/image/agent-launch.d/agent.sh` + `base/CONTRACT.md` | contract tests |
| health semantics | `stacks/<id>/stack.yaml` + `image/health.d/` | contract test + smoke |
| state paths | `stacks/<id>/image/state.d/*.paths` + `base/CONTRACT.md` | base ownership init + stack check |
| compose topology | `docker-compose.yml` + module `compose.yml` fragments | `make check` config matrix |
| build/release targets | `base/bake.hcl`, `stacks/<id>/bake.hcl`, `tooling/` | `docs/reference/targets.md` — generated |
| checks | `make check`, `tooling/check.sh` | `docs/reference/checks.md` — generated |
| decisions | `docs/adr/` | review |
