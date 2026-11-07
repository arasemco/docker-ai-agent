## Change

<!-- What changed, and which module owns it. -->

## Checks

- [ ] `make check`
- [ ] `make generate-check` when a reference or `.env.example` source changed
- [ ] `make test` / `make test-node22` when the base changed
- [ ] stack test target(s) when a stack image changed
- [ ] `make smoke PROFILE=<id>` when runtime behaviour changed
- [ ] version bump: `base/` change -> `BASE_VERSION`; stack image change -> that CLI version
- [ ] no host values in `base/`, `compose/common.yml`, `stacks/*/image`
