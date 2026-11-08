# Examples

Copy-paste material for deployment-specific values that the shared base
deliberately leaves out. Nothing here is used by the build, the tests or the
default stack, and none of it is a default: each file is a starting point to
edit.

| Path | What it shows |
|---|---|
| `env/proxy.env` | proxy values for a private network (one `PROXY=`, or per-scheme) |
| `compose/local.yml` | a machine-specific host overlay: the agent tree, extra binds, per-host tweaks |
| `compose/local.full.yml` | a fuller host overlay: GPU reservation, git identity and GPG signing configs, passphrase secret |
| `child-image/` | the smallest child image on top of agent-base, plus its stack |

Where the real files live (all gitignored):

- `.env` — copy `.env.example`, then merge whichever `env/` file applies
- `docker-compose.local.yml` — copy `examples/compose/local.yml` to the repository root
- `secrets/gpg_passphrase` — the signing key's passphrase, mode 600; see
  `compose/local.full.yml` for the generation command

See [docs/reference/compose-model.md](../docs/reference/compose-model.md#local-overrides) for the invocation.
