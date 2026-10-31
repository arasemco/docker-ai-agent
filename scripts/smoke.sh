#!/usr/bin/env bash
# smoke.sh — build agent-base and validate it in a real container.
#
#   ./scripts/smoke.sh              # build, start, selftest, wait for healthy
#   SMOKE_CLEAN=1 ./scripts/smoke.sh   # also drop the daemon's data volume
#
# The build-only checks (shellcheck, tool matrix) run in `make test`; this
# script adds what needs devices and a seccomp profile: rootless dockerd
# coming up, fuse-overlayfs as the storage driver, and a real image build.
set -euo pipefail

cd "$(dirname "$0")/.."

cleanup() {
    if [ "${SMOKE_CLEAN:-0}" = 1 ]; then
        docker compose down --timeout 0 --volumes
    else
        docker compose down --timeout 0
    fi
}
trap cleanup EXIT

echo "== validating compose config"
docker compose config >/dev/null

echo "== building and starting the harness"
docker compose up --detach --build --wait --wait-timeout 180 2>&1 | tail -n 5

echo "== in-container selftest (tools, no daemon)"
docker compose exec --no-TTY agent-base /usr/local/lib/agent-base/selftest.sh --no-docker

echo "== rootless docker"
if docker compose exec --no-TTY agent-base timeout 15 docker info >/dev/null 2>&1; then
    # The daemon is up, so the full selftest can prove the storage driver and
    # an actual image build.
    docker compose exec --no-TTY agent-base /usr/local/lib/agent-base/selftest.sh
else
    echo "   the in-container rootless daemon did not start."
    docker compose exec --no-TTY agent-base sh -c 'tail -n 5 ~/.docker/dockerd.log' 2>/dev/null | sed 's/^/     /' || true
    # Nested user namespaces are refused when the host's own Docker daemon is
    # rootless, so this is expected on such hosts and in CI sandboxes; the
    # agent itself is unaffected (agent-healthcheck warns instead of failing).
    # Set SMOKE_REQUIRE_DOCKER=1 wherever dockerd is supposed to work.
    if [ "${SMOKE_REQUIRE_DOCKER:-0}" = 1 ]; then
        echo "   FAIL: SMOKE_REQUIRE_DOCKER=1 and the daemon is down"
        exit 1
    fi
    echo "   SKIP: daemon unavailable here (host Docker is rootless?); set SMOKE_REQUIRE_DOCKER=1 to make this fatal"
fi

id="$(docker compose ps --quiet agent-base)"
echo "== healthcheck status"
status=""
for _ in $(seq 1 30); do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$id")"
    [ "$status" = healthy ] && break
    sleep 2
done
echo "   $status"
[ "$status" = healthy ] || {
    echo "container is not healthy; last log lines:"
    docker compose logs --tail 20 agent-base || true
    exit 1
}

echo
echo "OK — agent-base built, running, and healthy"
