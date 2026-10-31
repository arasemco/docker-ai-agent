#!/usr/bin/env bash
# smoke.sh — checks the running stack.
#
#   ./scripts/smoke.sh
#   SMOKE_REQUIRE_DOCKER=1 ./scripts/smoke.sh   # fail when the inner daemon is down
#
# dsh answers 401 to an unauthenticated request, so this does not probe the HTTP
# port. It runs the image's own healthcheck instead, which signs a browser-session
# cookie from the credentials file and requires 200 — a pass proves the server is
# up, the credentials store loads and browser auth accepts a valid session.
set -euo pipefail

cd "$(dirname "$0")/.."

compose() {
    scripts/compose.sh --with "${WITH:-daemon}" -- "$@"
}

echo "Validating compose config..."
compose config >/dev/null

echo "Checking container status..."
if ! compose ps --status running --services | grep -q '^dsh$'; then
    echo "dsh is not running; start with: make up"
    exit 1
fi

echo "Server reachability (401 expected before sign-in):"
port="${DSH_PORT:-}"
if [ -z "${port}" ] && [ -f .env ]; then
    port="$(sed -n 's/^[[:space:]]*DSH_PORT[[:space:]]*=[[:space:]]*//p' .env | tail -n 1 | tr -d "\"'")"
fi
port="${port:-3080}"
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${port}/" || true)"
if [ -z "${code}" ] || [ "${code}" = "000" ]; then
    echo "   no response on 127.0.0.1:${port}; recent log:"
    compose logs --tail 20 dsh || true
    exit 1
fi
echo "   HTTP ${code}"

echo "Healthcheck (signed session cookie, expects HTTP 200):"
if health="$(compose exec --no-TTY dsh node /usr/local/lib/dsh-healthcheck.mjs 2>&1)"; then
    echo "   ok"
elif printf '%s' "${health}" | grep -qiE 'yet|no client-connection|cannot read'; then
    # The record exists only after the first UI sign-in; until then the UI is up
    # but the authenticated check cannot pass.
    echo "   SKIP: the UI has not been signed in yet, so there is no browser-session"
    echo "         secret to sign a cookie with. Open the launch URL from 'make logs'."
    if [ "${SMOKE_REQUIRE_HEALTHCHECK:-0}" = 1 ]; then
        exit 1
    fi
else
    echo "   the healthcheck failed:"
    printf '%s\n' "${health}" | sed 's/^/   /'
    compose logs --tail 20 dsh || true
    exit 1
fi

echo "s6 services:"
compose exec --no-TTY dsh sh -c \
    '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'

echo -n "dsh version: "
compose exec --no-TTY dsh dsh --version

echo "inner daemon:"
daemon_up=0
for _ in $(seq 1 15); do
    if compose exec --no-TTY dsh timeout 10 docker info >/dev/null 2>&1; then
        daemon_up=1
        break
    fi
    sleep 2
done
if [ "${daemon_up}" -eq 1 ]; then
    compose exec --no-TTY dsh docker info --format '   Docker {{.ServerVersion}} / {{.Driver}}'
else
    if [ "${SMOKE_REQUIRE_DOCKER:-0}" = 1 ]; then
        echo "   FAIL: the inner daemon is not responding"
        exit 1
    fi
    echo "   SKIP: the inner daemon is not responding (see the container log)"
fi

echo "OK"
