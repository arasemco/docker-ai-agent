#!/usr/bin/env bash
# smoke.sh — checks the running opencode stack (build it first with
# `docker compose up -d --build`).
#
#   ./scripts/smoke.sh
#
# Probes the Web UI and the container healthcheck. A password-protected UI
# answers 401 to a bare request, so any HTTP status proves the server is up;
# 000/empty means nothing is listening.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Validating compose config..."
docker compose config >/dev/null

echo "Checking container status..."
if ! docker compose ps --status running --services | grep -q '^opencode$'; then
  echo "opencode is not running; start with: docker compose up -d --build"
  exit 1
fi

# Port from the shell, else .env, else the compose default.
port="${OPENCODE_PORT:-}"
if [ -z "$port" ] && [ -f .env ]; then
  port="$(sed -n 's/^[[:space:]]*OPENCODE_PORT[[:space:]]*=[[:space:]]*//p' .env | tail -n 1 | tr -d "\"'")"
fi
port="${port:-4096}"

url="http://127.0.0.1:${port}/"
echo "Probing ${url} ..."
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" || true)"
if [ -z "$code" ] || [ "$code" = "000" ]; then
  echo "no response from ${url}"
  exit 1
fi

id="$(docker compose ps --quiet opencode)"
status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")"
echo "Healthcheck: ${status}"
# Running in the container also validates that the agent user and the
# entrypoint's handoff work, independent of the UI.
docker compose exec --no-TTY opencode opencode --version

echo "OK (HTTP ${code}, health ${status})"
