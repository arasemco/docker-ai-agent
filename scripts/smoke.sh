#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Validating compose config..."
docker compose config >/dev/null

echo "Checking container status..."
if ! docker compose ps --status running --services | grep -q '^opencode$'; then
  echo "opencode is not running; start with: docker compose up -d"
  exit 1
fi

port="${OPENCODE_PORT:-4096}"
url="http://localhost:${port}/"
echo "Probing ${url} ..."

code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" || true)"
if [ -z "$code" ] || [ "$code" = "000" ]; then
  echo "no response from ${url}"
  exit 1
fi

echo "OK (HTTP ${code})"
