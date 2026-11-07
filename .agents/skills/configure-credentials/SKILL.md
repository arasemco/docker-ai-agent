---
name: configure-credentials
description: Get a DeepSeek API key into dsh the way the image expects — through the UI into $DSH_HOME/.credentials.yaml — and verify it without putting the key in the environment. Use when dsh has no usable model, reports an invalid key, or `make test-dsh` cannot find credentials.
metadata:
  area: config
  files: docker-compose.yml, stacks/dsh/image/Dockerfile, makefile
---

# Configure credentials

## Where the key lives

`$DSH_HOME/.credentials.yaml` (`/home/agent/.dsh/.credentials.yaml` in the
container), under `refs.DEEPSEEK_API_KEY`, owned by the agent user with mode
0600. The UI writes it from Settings → Models. It lives in the `dsh-home` volume
and survives container recreation.

`DEEPSEEK_API_KEY` is deliberately not read from the environment: the inherited
environment outranks the file, so setting it would hide whether the file path
works — which is exactly what the image's `test` stage checks.

## Steps

1. `make up`, open the UI at <http://localhost:3080> using the launch URL from
   `make logs`, and sign in.
2. Settings → Models → add the DeepSeek provider and paste the key.
3. Confirm the file exists and has the expected shape:

   ```bash
   docker compose --profile dsh exec --no-TTY dsh sh -c 'ls -l ~/.dsh/.credentials.yaml; grep -c DEEPSEEK_API_KEY ~/.dsh/.credentials.yaml'
   ```

4. Verify against the real API and a headless run:

   ```bash
   make test-dsh      # reads the volume if no local copy exists
   ```

   Expect `test: API key valid (GET /models -> 200)` and
   `test: dsh headless answered: OK`.

## When the key comes from elsewhere

- **An existing credentials file:** `DSH_CREDENTIALS=/path/to/.credentials.yaml make test-dsh`.
- **A host directory as home:** point `DSH_HOME_HOST` at it (owned by uid 1000);
  the file then lives there and the volume is not used.

## Pitfalls

- Mode must stay 0600 with owner uid 1000: credentials-local refuses a file with
  any group or other permission bit.
- A key in `.env` has no effect; it must reach the file.
