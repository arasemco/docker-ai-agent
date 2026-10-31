# AGENTS.md

Instructions for AI coding agents working in this repository.

**Read [`.agents/README.md`](.agents/README.md) first** — it has the repository map,
the invariants that are easy to break, and the checks to run. User-facing
documentation lives in [`docs/`](docs/index.md); this file is only the short
version.

Task-specific skills are in [`.agents/skills/`](.agents/skills/): load the one
that matches the job (`work-on-the-image`, `compose-fragments`,
`build-and-publish`, `run-and-debug`, `child-image`) before starting.

## Hard rules

1. The base image contains no CLI: an agent stack lives under `stacks/<name>/`
   and builds `FROM agent-base`.
2. Do not end a Dockerfile with `USER 1000:1000`; `/init` must be PID 1 as root.
3. No host-specific values in the core: no IPs, hostnames, registry paths or
   personal directories outside `examples/`.
4. Compose fragments each own exactly one concern and declare the volumes they
   mount.
5. Comments and docs describe what the code does and why it must — not the
   history of the change or a conversation.
6. Bump `BASE_VERSION` in `docker-bake.hcl` whenever `image/` changes.
7. Keep everything pinned: base image by digest, s6 by version + sha256, CLIs by
   exact version.

## Verify before you finish

```bash
shellcheck image/rootfs/usr/local/bin/* scripts/*.sh
scripts/bake.sh test     # builds the image, runs shellcheck + tool matrix
make smoke               # real container: services, health, tool matrix
```

`make smoke` printing `SKIP` for the rootless daemon is expected on hosts whose
own Docker is rootless.
