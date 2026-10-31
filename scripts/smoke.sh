#!/usr/bin/env bash
# smoke.sh — checks the running stack.
#
#   ./scripts/smoke.sh
#   SMOKE_REQUIRE_DOCKER=1 ./scripts/smoke.sh   # fail when the inner daemon is down
#
# Probes the Web UI, the container healthcheck and both s6 services. A
# password-protected UI answers 401 to a bare request, so any HTTP status proves
# the server listens; 000/empty means nothing is there.
set -euo pipefail

cd "$(dirname "$0")/.."

compose() {
    scripts/compose.sh --with "${WITH:-daemon}" -- "$@"
}

echo "Validating compose config..."
compose config >/dev/null

echo "Checking container status..."
if ! compose ps --status running --services | grep -q '^opencode$'; then
    echo "opencode is not running; start with: make up"
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
    compose logs --tail 20 opencode || true
    exit 1
fi

echo "s6 services:"
compose exec --no-TTY opencode sh -c \
    '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'

echo "inner daemon:"
daemon_up=0
for _ in $(seq 1 15); do
    if compose exec --no-TTY opencode timeout 10 docker info >/dev/null 2>&1; then
        daemon_up=1
        break
    fi
    sleep 2
done
if [ "${daemon_up}" -eq 1 ]; then
    compose exec --no-TTY opencode docker info --format '   Docker {{.ServerVersion}} / {{.Driver}}'
else
    if [ "${SMOKE_REQUIRE_DOCKER:-0}" = 1 ]; then
        echo "   FAIL: the inner daemon is not responding"
        exit 1
    fi
    echo "   SKIP: the inner daemon is not responding (see the container log)"
fi

echo -n "opencode version: "
compose exec --no-TTY opencode opencode --version

id="$(compose ps --quiet opencode)"
status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")"
echo "Healthcheck: ${status}"
if [ "$status" != healthy ]; then
    compose logs --tail 20 opencode || true
    exit 1
fi

echo "OK (HTTP ${code}, health ${status})"
