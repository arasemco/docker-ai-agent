# Examples

Copy-paste material for values the shared base image deliberately leaves out.
Nothing here is used by the build, the tests or the default stack, and none of it
is a default: each file is a starting point to edit.

| Path | What it shows |
|---|---|
| `env/proxy.env` | proxy values for a private network |
| `env/credentials.env` | where the API key must **not** go, and why |
| `compose/local.yml` | extra binds and per-host tweaks |
| `credentials.example.yaml` | the shape of `$DSH_HOME/.credentials.yaml` |

Real files live in `.env` (gitignored) and `compose/local.yml` (gitignored); the
credentials file is written by the UI into the `dsh-home` volume.
