#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Validating compose config..."
docker compose config >/dev/null

echo "Checking container status..."
if docker compose ps --status running --services | grep -q '^opencode$'; then
  port="${OPENCODE_PORT:-4096}"
  echo "Probing http://localhost:${port} ..."
  curl -fsS -o /dev/null "http://localhost:${port}" && echo "OK"
else
  echo "opencode is not running; start with: docker compose up -d"
  exit 1
fi
