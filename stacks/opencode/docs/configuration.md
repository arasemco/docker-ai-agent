# Configuration

## Environment

Everything is optional; the defaults work with no configuration.

| Variable | Default | Meaning |
|---|---|---|
| `OPENCODE_PORT` | `4096` | port the UI listens on and is published on |
| `OPENCODE_BIND_IP` | `127.0.0.1` | interface the port is published on |
| `OPENCODE_SERVER_PASSWORD` | `changeme123` | HTTP basic auth password for the UI |
| `AGENT_BASE` | `agent-base:1.5.0` | base image the Dockerfile builds from |
| `OPENCODE_VERSION` | `1.19.5` | exact `opencode-ai` version from npm |
| `OPENCODE_IMAGE` | `opencode:local` | tag for the built image |
| `OPENCODE_CONFIG_HOST` | `opencode-config` | volume or host path for the config dir |
| `OPENCODE_DATA_HOST` | `opencode-data` | volume or host path for the data dir |
| `OPENCODE_STATE_HOST` | `opencode-state` | volume or host path for the state dir |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY` | – | provider credentials, passed through empty |
| `OLLAMA_BASE_URL`, `OLLAMA_API_KEY` | – | local OpenAI-compatible endpoint |

The sandbox has its own switches (`AGENT_DOCKERD`, `AGENT_HEALTHCHECK`,
`AGENT_CPUS`, proxy variables…), documented in
[agent-base's configuration reference](../../../docs/configuration.md).

## State

| Path | Volume | Holds |
|---|---|---|
| `/home/agent/.config/opencode` | `opencode-config` | provider and model configuration (`opencode.jsonc`) |
| `/home/agent/.local/share/opencode` | `opencode-data` | `auth.json`, session database, snapshots |
| `/home/agent/.local/state/opencode` | `opencode-state` | XDG state |
| `/home/agent/workspace` | – | working directory for the agent |

The volumes are created with the agent user's ownership on first use. Point a
`*_HOST` variable at an existing host directory (owned by uid 1000) to bind
instead.

## Providers

No provider configuration is baked into the image: which providers exist, and
where they run, is deployment-specific. Two ways to set them up:

1. **In the UI.** Sign in and configure providers there; credentials land in
   `auth.json` inside the `opencode-data` volume and survive recreation.
2. **Seed a config file.** Copy [examples/config/opencode.jsonc](../examples/config/opencode.jsonc),
   adjust the provider block and model list, then make it available at
   `/home/agent/.config/opencode/opencode.jsonc` — for example by placing it in
   the config volume or binding it read-only in `compose/local.yml`.

The example uses an OpenAI-compatible endpoint read from `OLLAMA_BASE_URL` and
`OLLAMA_API_KEY`, so the endpoint can move without editing the file.

## Ports and password

The UI is published on loopback by default because the password has a weak
fallback. Set a real `OPENCODE_SERVER_PASSWORD` before setting
`OPENCODE_BIND_IP=0.0.0.0`. A password-protected UI answers `401` to a bare
request, which is what `scripts/smoke.sh` expects.

## Compose

Every service extends the shared `common` service (`compose.common.yml`); this
stack's service adds only its build, port, credentials and state volumes. Proxy
values come from `.env` or the environment:

```bash
make up                          # build and start the stack
PROXY=http://proxy:3128 make up  # route the agent's outbound calls through it
```

A gitignored `compose/local.yml` can be added with `-f`; start from
[examples/compose/local.yml](../examples/compose/local.yml).
