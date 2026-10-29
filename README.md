# opencode container

Runs the OpenCode web UI in a container with an inner (rootless) Docker daemon, persistent state, and optional Squid proxy.

## Quick start

```bash
cp .env.example .env
# edit .env as needed
docker compose up -d --build
```

Open http://localhost:${OPENCODE_PORT:-4096}.

## Configuration

- Provider config: `opencode.jsonc` (seeded into the config volume on first run).
- Environment variables: see `.env.example`.
- Proxy: set `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` in `.env`. `NO_PROXY` must include `localhost,127.0.0.1`.

## Smoke test

```bash
./scripts/smoke.sh
```

## Rebuild after changes

```bash
docker compose up -d --build
```