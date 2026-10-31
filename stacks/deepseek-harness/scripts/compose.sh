#!/usr/bin/env bash
# =============================================================================
# compose.sh — this stack, assembled from agent-base's compose fragments
# =============================================================================
# A thin wrapper around agent-base/scripts/compose.sh, which does the work:
# fragment order, service renaming (the fragments are keyed "agent-base"), and
# merging a gitignored compose/local.yml. Only the paths and the service name
# are fixed here.
#
#   ./scripts/compose.sh -- up -d --build
#   ./scripts/compose.sh --with daemon,proxy -- up -d
#   WITH=daemon,mounts make up
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

# `make` passes WITH; the fragments' own convention is COMPOSE_WITH.
export COMPOSE_WITH="${COMPOSE_WITH:-${WITH:-daemon}}"

exec ../agent-base/scripts/compose.sh \
    --service dsh \
    --fragments ../agent-base/compose \
    --file docker-compose.yml \
    "$@"
