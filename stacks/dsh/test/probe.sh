#!/bin/bash
set -euo pipefail
port="${DSH_PORT:-3080}"
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${port}/" || true)"
echo "dsh: HTTP ${code:-000} (401 expected before sign-in)"
docker compose --profile dsh exec --no-TTY dsh node /usr/local/lib/dsh-healthcheck.mjs || {
    echo "dsh: healthcheck fragment did not pass (sign in first?)" >&2
    exit 1
}
docker compose --profile dsh exec --no-TTY dsh dsh --version
