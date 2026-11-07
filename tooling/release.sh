#!/bin/bash
# Release gate: the tag must name the declared base version, then build (and
# optionally push) the base variants and every stack with attestations.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
# shellcheck disable=SC1091
. "${ROOT}/versions.env"
tag="$(git describe --tags --exact-match 2>/dev/null || true)"
[ "${tag}" = "v${BASE_VERSION}" ] || { echo "release: HEAD tag '${tag}' != v${BASE_VERSION}" >&2; exit 1; }

push_args=()
for arg in "$@"; do
    [ "${arg}" = "--push" ] && push_args=(--push --provenance=mode=max --sbom=generator)
done

tooling/bake.sh agent-base agent-base-node22 "${push_args[@]}"
# shellcheck disable=SC2046
tooling/bake.sh $(tooling/stacks.sh --list) "${push_args[@]}"
