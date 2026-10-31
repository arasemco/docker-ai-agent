#!/usr/bin/env bash
# smoke.sh — checks a running stack, chosen by profile.
#
#   scripts/smoke.sh opencode    # UI answers, CLI version, services, inner daemon
#   scripts/smoke.sh dsh         # authenticated healthcheck, CLI version, services
#
#   SMOKE_REQUIRE_DOCKER=1       # fail instead of skipping when dockerd is down
#   SMOKE_REQUIRE_HEALTHCHECK=1  # dsh: fail when the UI was never signed in
set -euo pipefail

cd "$(dirname "$0")/.."

profile="${1:-opencode}"
case "$profile" in
    opencode|dsh) service="$profile" ;;
    *) echo "usage: $0 [opencode|dsh]" >&2; exit 2 ;;
esac

compose() {
    docker compose --profile "$profile" "$@"
}

echo "Validating compose config..."
compose config >/dev/null

echo "Checking container status..."
if ! compose ps --status running --services | grep -qx "$service"; then
    echo "$service is not running; start with: make up PROFILE=$profile"
    exit 1
fi

if [ "$profile" = opencode ]; then
    port="${OPENCODE_PORT:-4096}"
    url="http://127.0.0.1:${port}/"
    echo "Probing ${url} ..."
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" || true)"
    if [ -z "$code" ] || [ "$code" = "000" ]; then
        echo "   no response from ${url}"
        compose logs --tail 20 "$service" || true
        exit 1
    fi
    echo "   HTTP ${code} (401 is expected before sign-in)"
    echo -n "   opencode version: "
    compose exec --no-TTY "$service" opencode --version
else
    port="${DSH_PORT:-3080}"
    echo "Server reachability (401 expected before sign-in):"
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${port}/" || true)"
    echo "   HTTP ${code:-000}"
    echo "Healthcheck (signed session cookie, expects HTTP 200):"
    if health="$(compose exec --no-TTY "$service" node /usr/local/lib/dsh-healthcheck.mjs 2>&1)"; then
        echo "   ok"
    elif printf '%s' "$health" | grep -qiE 'yet|no client-connection|cannot read'; then
        echo "   SKIP: the UI has not been signed in yet, so there is no"
        echo "         browser-session secret. Open the launch URL from 'make logs'."
        [ "${SMOKE_REQUIRE_HEALTHCHECK:-0}" = 1 ] && exit 1
    else
        echo "   failed:"
        printf '%s\n' "$health" | sed 's/^/   /'
        exit 1
    fi
    echo -n "   dsh version: "
    compose exec --no-TTY "$service" dsh --version
fi

echo "s6 services:"
compose exec --no-TTY "$service" sh -c \
    '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'

echo "inner daemon:"
daemon_up=0
for _ in $(seq 1 15); do
    if compose exec --no-TTY "$service" timeout 10 docker info >/dev/null 2>&1; then
        daemon_up=1
        break
    fi
    sleep 2
done
if [ "$daemon_up" -eq 1 ]; then
    compose exec --no-TTY "$service" docker info --format '   Docker {{.ServerVersion}} / {{.Driver}}'
elif [ "${SMOKE_REQUIRE_DOCKER:-0}" = 1 ]; then
    echo "   FAIL: the inner daemon is not responding"
    exit 1
else
    echo "   SKIP: the inner daemon is not responding (see the container log)"
fi

echo "OK ($profile)"
