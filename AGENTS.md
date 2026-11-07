# AGENTS.md

Instructions for AI coding agents working in this repository.

Read [`.agents/README.md`](.agents/README.md) first: it maps the module tree,
the invariants and the checks. User documentation lives in [`docs/`](docs/index.md).

## Hard rules

1. The base image contains no agent CLI. A CLI lives in a stack module under
   `stacks/<id>/` and builds `FROM` the base image.
2. Do not end a Dockerfile with `USER 1000:1000`; `/init` must stay PID 1 as root.
3. No host-specific values in the core: no IPs, hostnames, registry paths,
   personal directories or host binds outside `examples/` and the ignored host
   overlay. The generic core starts at `base/`, `compose/common.yml` and
   `stacks/*/image`.
4. `versions.env` is the only file that carries a version, digest or image
   reference. Dockerfiles, compose and bake take the values as required inputs.
5. The base contract in `base/CONTRACT.md` is versioned. A breaking change bumps
   `base/CONTRACT` and the base major version; every stack asserts the contract
   in its test stage.
6. One module per fact: a stack manifest, a compose fragment, a bake fragment,
   a launch file, a state manifest, a probe and its docs live in the same module.
   Discover stacks through `tooling/stacks.sh`, never enumerate them by hand.
7. Keep inputs pinned: base by digest, s6 by version + sha256, CLIs by exact
   version. The registry prefix and OCI labels come from `tooling/provenance.sh`.
8. Record who did the work in every commit. There is no in-repo wrapper: use the
   global `git-commit` skill, or apply its rule directly — the model id as
   author, the vendor no-reply address as email, a `Co-authored-by` trailer for
   human-directed work, `git -c user.name=... user.email=...` for autonomous
   work.

## Verify before you finish

```bash
make check                  # hermetic: links, manifests, versions, compose, bake, tests
make generate-check         # reference pages and .env.example are current
tooling/bake.sh test        # base image test stage
tooling/bake.sh test-node22 # Node 22 base test stage
make smoke PROFILE=<id>     # running stack; SKIP for the daemon is expected on rootless hosts
```

Image builds: `tooling/bake.sh <target>`; running: `make up PROFILE=<id>`. Compose
carries no `build:` keys — the bake wrapper is the only build entry point.
