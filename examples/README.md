# Examples

Copy-paste material for things a shared base image has no business deciding.
Nothing here is used by the build, the tests or the default stack, and none of
it is a default: it is one operator's shape, meant to be edited.

| Path | What it shows |
|---|---|
| `env/proxy.env` | proxy values for a private network (one `PROXY=`, or per-scheme) |
| `compose/local.yml` | a machine-specific overlay: extra binds, per-host tweaks |
| `child-image/` | the smallest child image on top of agent-base, plus its stack |

Where the real files live (both gitignored):

- `.env` — copy `.env.example`, then merge whichever `env/` file applies
- `compose/local.yml` — copy `compose/local.yml` from here

See the repository README's "Overrides" section for the full picture.
