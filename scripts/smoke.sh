#!/usr/bin/env bash
# smoke.sh — checks the running opencode stack (build it first: `make up`).
#
#   ./scripts/smoke.sh
#
# Probes the Web UI and the container healthcheck. A password-protected UI
# answers 401 to a bare request, so any HTTP status proves the server listens;
# 000/empty means nothing is there.
set -euo pipefail

cd "$(dirname "$0")/.."

# Same assembly as the makefile: agent-base fragments (WITH, default daemon)
# plus this stack, with compose/local.yml merged by the wrapper when present.
compose() {
    scripts/compose.sh --with "${WITH:-daemon}" -- "$@"
}

echo "Validating compose config..."
compose config >/dev/null

echo "Checking container status..."
if ! compose ps --status running --services | grep -q '^opencode$'; then
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

id="$(compose ps --quiet opencode)"
status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")"
echo "Healthcheck: ${status}"

echo "s6 services:"
compose exec --no-TTY opencode sh -c \
    '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'

echo -n "opencode version: "
compose exec --no-TTY opencode opencode --version

if [ "$status" != healthy ]; then
    echo "container is not healthy; last log lines:"
    compose logs --tail 20 opencode || true
    exit 1
fi

echo "OK (HTTP ${code}, health ${status})"
