---
name: configure-providers
description: Set up OpenCode providers — a local OpenAI-compatible endpoint, hosted API keys, or a seeded opencode.jsonc — without baking deployment values into the image. Use when the UI shows no usable model or a provider must be added or moved.
metadata:
  area: config
  files: stacks/opencode/image/, docker-compose.yml, docker-compose.local.yml
---

# Configure providers

## Rule

The image carries no provider configuration: which providers exist, and where
they run, is deployment-specific. Configuration has two homes, both outside the
image:

- **`~/.config/opencode/opencode.jsonc`** inside the container — the provider
  block and model list (volume `opencode-config`).
- **`~/.local/share/opencode/auth.json`** — credentials written by the UI
  (volume `opencode-data`).

## Option A — configure in the UI

Start the stack, open the Web UI, add the provider and its key. The key is
persisted in `auth.json` inside the data volume and survives recreation. Nothing
in this repository changes.

## Option B — seed a config file

1. Keep a JSONC file you control (for example `compose/opencode.jsonc`,
   gitignored).
2. Adjust the provider block: `baseURL` and `apiKey` read `OLLAMA_BASE_URL` and
   `OLLAMA_API_KEY`, so the endpoint can move without editing the file.
3. Make the file available at `/home/agent/.config/opencode/opencode.jsonc`,
   either by writing it into the `opencode-config` volume or by binding it in
   `docker-compose.local.yml`:

   ```yaml
   services:
     opencode:
       volumes:
         - ./compose/opencode.jsonc:/home/agent/.config/opencode/opencode.jsonc:ro
   ```

4. Put the endpoint and keys in `.env` (see `docs/reference/configuration.md`), then
   `make up`.

## Verify

```bash
docker compose --profile opencode exec --no-TTY opencode ls -l /home/agent/.config/opencode
docker compose --profile opencode exec --no-TTY opencode printenv OLLAMA_BASE_URL
make smoke
```

Then open the UI and check that the model list contains the configured models.

## Pitfalls

- `OPENCODE_CONFIG_HOST` may bind a host directory over the config volume; on
  those stacks edit the host directory, not the container.
- A malformed `opencode.jsonc` (JSONC: comments allowed, trailing commas are
  not) makes the CLI ignore the file silently in some versions — check the log.
- Keys in `.env` are visible to `docker inspect` and any process in the
  container; prefer UI-entered keys where that matters.
