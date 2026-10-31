#!/usr/bin/env bash
# =============================================================================
# compose.sh — this stack, assembled with agent-base's compose fragments
# =============================================================================
# Thin wrapper: agent-base/scripts/compose.sh does the work (fragment order,
# service renaming, compose/local.yml merge). The only thing fixed here is the
# service name and where the fragments and this stack's file live.
#
#   ./scripts/compose.sh -- up -d --build
#   ./scripts/compose.sh --with daemon,proxy,limits -- up -d
#   WITH=daemon,mounts make up
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

# `make` passes WITH, the fragments' own convention is COMPOSE_WITH.
export COMPOSE_WITH="${COMPOSE_WITH:-${WITH:-daemon}}"

exec ../agent-base/scripts/compose.sh \
    --service opencode \
    --fragments ../agent-base/compose \
    --file docker-compose.yml \
    "$@"
