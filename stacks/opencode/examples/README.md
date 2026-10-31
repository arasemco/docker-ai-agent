# Examples

Copy-paste material for values the shared base image deliberately leaves out.
Nothing here is used by the build, the tests or the default stack, and none of it
is a default: each file is a starting point to edit.

| Path | What it shows |
|---|---|
| `config/opencode.jsonc` | a provider block and model list for a local OpenAI-compatible server |
| `env/providers.env` | provider credentials and a local endpoint |
| `env/proxy.env` | proxy values for a private network |
| `compose/local.yml` | a machine-specific overlay: extra binds, per-host tweaks |

Where the real files live (both gitignored):

- `.env` — copy `.env.example`, then merge whichever `env/` file applies
- `compose/local.yml` — copy `compose/local.yml` from here

See the repository README and `docs/` for the full picture.
