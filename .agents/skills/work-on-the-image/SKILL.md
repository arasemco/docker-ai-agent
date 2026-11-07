---
name: work-on-the-image
description: Change the agent-base image — packages, the agent user, s6 services, the launch/health/state contracts, or a runtime default — and land it with the required version bump and checks. Use when a task touches base/ or changes a runtime default.
metadata:
  area: image
  files: base/Dockerfile, base/rootfs/, base/CONTRACT.md, versions.env
---

# Work on the image

## Ground rules

- The base is generic: no host names, IPs, registry paths, personal directories
  or host binds. Host values live in the host overlay.
- `versions.env` is the only pin source. The Dockerfile takes required `ARG`s;
  never add a default copy of a pin.
- The identity is frozen: `agent`, uid/gid 1000, home `/home/agent`.
- No `USER` at the end; `/init` stays PID 1 as root.
- A breaking contract change bumps `base/CONTRACT` and the base major version.

## Where things live

| Concern | File |
|---|---|
| base inputs, package blocks, ENV | `base/Dockerfile`, `versions.env` |
| launch, health, state, lib | `base/rootfs/usr/local/bin/`, `base/rootfs/usr/local/lib/agent-base/` |
| boot preparation | `base/rootfs/etc/cont-init.d/{10-ownership,20-subid,30-workspace}` |
| longruns | `base/rootfs/etc/services.d/{dockerd,agent}/{run,finish}` |
| contract | `base/CONTRACT.md`, `base/CONTRACT` |
| tests | `base/tests/{lint.sh,contract.sh}` |

## Recipes

**Package.** Add it to the matching apt block in `base/Dockerfile`; keep the
layer grouping.

**Service.** Add `base/rootfs/etc/services.d/<name>/run`, plus `finish` if it
needs restart policy. `base/tests/lint.sh` discovers scripts; do not edit a list.

**Runtime default.** Set the image ENV, add the knob to `config/knobs.env`, and
run `make generate`.

**Launch/health/state.** Change the contract in `base/CONTRACT.md` and the base
dispatcher, then port every stack in the same change.

## Verify

```bash
make check
tooling/bake.sh test
tooling/bake.sh test-node22
make smoke PROFILE=<id>
```
