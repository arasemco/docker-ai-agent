#!/usr/bin/env bash
# smoke.sh — build agent-base and validate it in a real container.
#
#   ./scripts/smoke.sh                 # build, start, selftest, check health
#   SMOKE_CLEAN=1 ./scripts/smoke.sh   # also drop the daemon's data volume
#   SMOKE_REQUIRE_DOCKER=1 ...         # fail instead of skipping when the
#                                      # in-container daemon cannot start
#
# The build-only checks (shellcheck, tool matrix) run in `scripts/bake.sh test`;
# this script adds what needs devices and a seccomp profile: s6 bringing both
# services up, fuse-overlayfs as the storage driver, and a real image build.
set -euo pipefail

cd "$(dirname "$0")/.."

# Same assembly the makefile uses: fragments (WITH, default daemon) plus the
# image + fragments; scripts/compose.sh also merges compose/local.yml when present.
compose() {
    scripts/compose.sh --with "${WITH:-daemon}" --file compose/image.yml --file compose/harness.yml -- "$@"
}

cleanup() {
    if [ "${SMOKE_CLEAN:-0}" = 1 ]; then
        compose down --timeout 0 --volumes
    else
        compose down --timeout 0
    fi
}
trap cleanup EXIT

echo "== validating compose config"
compose config >/dev/null

echo "== building and starting the stack"
compose up --detach --build --wait --wait-timeout 180 2>&1 | tail -n 5

echo "== in-container selftest (tools, no daemon)"
compose exec --no-TTY agent-base /usr/local/lib/agent-base/selftest.sh --no-docker

echo "== s6 services"
compose exec --no-TTY agent-base sh -c \
    '/command/s6-svstat /run/service/dockerd; /command/s6-svstat /run/service/agent'

echo "== rootless docker"
if compose exec --no-TTY agent-base timeout 15 docker info >/dev/null 2>&1; then
    # The daemon is up, so the full selftest can prove the storage driver and
    # an actual image build.
    compose exec --no-TTY agent-base /usr/local/lib/agent-base/selftest.sh
else
    echo "   the in-container rootless daemon did not start."
    compose exec --no-TTY agent-base sh -c 'tail -n 5 ~/.docker/dockerd.log' 2>/dev/null | sed 's/^/     /' || true
    # Nested user namespaces are refused when the host's own Docker daemon is
    # rootless, so this is expected on such hosts and in CI sandboxes; the
    # agent itself is unaffected (agent-healthcheck warns instead of failing).
    if [ "${SMOKE_REQUIRE_DOCKER:-0}" = 1 ]; then
        echo "   FAIL: SMOKE_REQUIRE_DOCKER=1 and the daemon is down"
        exit 1
    fi
    echo "   SKIP: daemon unavailable here (host Docker rootless?); set SMOKE_REQUIRE_DOCKER=1 to make this fatal"
fi

id="$(compose ps --quiet agent-base)"
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
    compose logs --tail 20 agent-base || true
    exit 1
}

echo
echo "OK — agent-base built, running, and healthy"
