#!/bin/bash
# Shared runtime harness: checks a running stack, then delegates to the stack's
# own probe. SMOKE_REQUIRE_DOCKER=1 fails when the inner daemon is down.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
profile="${1:-opencode}"
service="$( [ "$profile" = base ] && echo agent-base || echo "$profile" )"
eval "$(tooling/versions.sh --export)"

echo "validating compose config..."
docker compose --profile "$profile" config >/dev/null
echo "checking container status..."
if ! docker compose --profile "$profile" ps --status running --services | grep -qx "$service"; then
    echo "$service is not running; start with: make up PROFILE=$profile"
    exit 1
fi
echo "s6 services:"
docker compose --profile "$profile" exec --no-TTY "$service" sh -c \
    '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'
echo "inner daemon:"
daemon_up=0
for _ in $(seq 1 15); do
    if docker compose --profile "$profile" exec --no-TTY "$service" timeout 10 docker info >/dev/null 2>&1; then daemon_up=1; break; fi
    sleep 2
done
if [ "$daemon_up" -eq 1 ]; then
    docker compose --profile "$profile" exec --no-TTY "$service" docker info --format '   Docker {{.ServerVersion}} / {{.Driver}}'
elif [ "${SMOKE_REQUIRE_DOCKER:-0}" = 1 ]; then
    echo "   FAIL: the inner daemon is not responding"; exit 1
else
    echo "   SKIP: the inner daemon is not responding"
fi
if [ -x "stacks/${profile}/test/probe.sh" ]; then
    "stacks/${profile}/test/probe.sh"
fi
echo "OK ($profile)"
