#!/bin/bash
# Single entry point to versions.env. Usage:
#   tooling/versions.sh --export          shell exports for eval
#   tooling/versions.sh --ref NAME TAG [VARIANT]
#   tooling/versions.sh --version KEY
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "${ROOT}/versions.env"
# shellcheck disable=SC1091
. "${ROOT}/tooling/provenance.sh"

image_ref() {
    local name="$1" tag="${2:-${TAG}}" variant="${3:-}" suffix=""
    if [ -n "${variant}" ]; then suffix="-${variant}"; fi
    if [ -n "${REGISTRY}" ]; then
        printf '%s/%s:%s%s' "${REGISTRY}" "${name}" "${tag}" "${suffix}"
    else
        printf '%s:%s%s' "${name}" "${tag}" "${suffix}"
    fi
}

export_all() {
    provenance_setup
    export BASE_VERSION AGENT_CONTRACT TAG AGENT_USER AGENT_UID AGENT_GID
    export DEBIAN_REF S6_OVERLAY_VERSION S6_SHA256_NOARCH S6_SHA256_X86_64 S6_SHA256_AARCH64
    export DOCKER_VERSION UV_VERSION NODE_REF
    export OPENCODE_VERSION DSH_VERSION CLAUDE_VERSION PNPM_VERSION LICENSES
    AGENT_BASE_IMAGE="$(image_ref agent-base "${BASE_VERSION}")"
    AGENT_BASE_NODE22_IMAGE="$(image_ref agent-base "${BASE_VERSION}" node22)"
    AGENT_IMAGE="$(image_ref agent-base "${TAG}")"
    OPENCODE_IMAGE="$(image_ref opencode "${TAG}")"
    DSH_IMAGE="$(image_ref dsh "${TAG}")"
    CLAUDE_IMAGE="$(image_ref claude "${TAG}")"
    export AGENT_BASE_IMAGE AGENT_BASE_NODE22_IMAGE AGENT_IMAGE OPENCODE_IMAGE DSH_IMAGE CLAUDE_IMAGE
}

case "${1:-}" in
    --export)
        export_all
        for v in BASE_VERSION AGENT_CONTRACT TAG AGENT_USER AGENT_UID AGENT_GID DEBIAN_REF \
                 S6_OVERLAY_VERSION S6_SHA256_NOARCH S6_SHA256_X86_64 S6_SHA256_AARCH64 \
                 DOCKER_VERSION UV_VERSION NODE_REF OPENCODE_VERSION DSH_VERSION \
                 CLAUDE_VERSION PNPM_VERSION LICENSES GIT_SHA GIT_REF AUTHOR SOURCE_URL \
                 REGISTRY VENDOR BUILD_CREATED AGENT_BASE_IMAGE AGENT_BASE_NODE22_IMAGE \
                 AGENT_IMAGE OPENCODE_IMAGE DSH_IMAGE CLAUDE_IMAGE; do
            printf "export %s='%s'\n" "$v" "${!v}"
        done
        ;;
    --ref)
        shift
        name="${1:?name}"; tag="${2:-${TAG}}"; variant="${3:-}"
        if [ -n "${REGISTRY:-}" ]; then
            printf '%s/%s:%s%s\n' "${REGISTRY}" "$name" "$tag" "${variant:+'-'$variant}"
        else
            printf '%s:%s%s\n' "$name" "$tag" "${variant:+'-'$variant}"
        fi
        ;;
    --version)
        key="${2:?key}"
        printf '%s\n' "${!key:?unknown version key $key}"
        ;;
    *)
        echo "usage: $0 --export | --ref NAME TAG [VARIANT] | --version KEY" >&2
        exit 2
        ;;
esac
