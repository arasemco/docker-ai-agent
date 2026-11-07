#!/bin/bash
# Thin build wrapper: load versions, derive provenance, discover per-module bake
# fragments and hand everything to buildx bake. The only build entry point.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
# shellcheck disable=SC1091
. "${ROOT}/versions.env"
# shellcheck disable=SC1091
. "${ROOT}/tooling/provenance.sh"
provenance_setup
export BASE_VERSION AGENT_CONTRACT TAG AGENT_USER AGENT_UID AGENT_GID DEBIAN_REF
export S6_OVERLAY_VERSION S6_SHA256_NOARCH S6_SHA256_X86_64 S6_SHA256_AARCH64
export DOCKER_VERSION UV_VERSION NODE_REF OPENCODE_VERSION DSH_VERSION
export CLAUDE_VERSION PNPM_VERSION LICENSES

files=("docker-bake.hcl")
for f in base/bake.hcl stacks/*/bake.hcl; do
    [ -f "$f" ] && files+=("$f")
done
args=()
for f in "${files[@]}"; do args+=(-f "$f"); done
exec docker buildx bake "${args[@]}" "$@"
