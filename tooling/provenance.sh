#!/bin/bash
# ---------------------------------------------------------------------------
# Provenance for OCI labels and the registry prefix. Sourced by the wrappers;
# never executed directly. HCL cannot run git, so these values are derived here
# and exported to bake.
# ---------------------------------------------------------------------------
normalize_remote() {
    local url="$1"
    [ -n "$url" ] || return 0
    case "$url" in
        *://*) ;;
        *@*:*) url="ssh://${url%%:*}/${url#*:}" ;;
    esac
    url="$(printf '%s' "$url" | sed -E 's#^([a-zA-Z][a-zA-Z0-9+.-]*://)[^/@]*@#\1#')"
    url="$(printf '%s' "$url" | sed -E 's#^(ssh|git)://#https://#; s#^https://([^/:]+):22/#https://\1/#')"
    url="${url%.git}"
    url="${url%/}"
    printf '%s' "$url"
}

derive_registry() {
    local url="$1" rest host path owner repo
    [ -n "$url" ] || return 0
    rest="${url#*://}"
    host="${rest%%/*}"
    [ -n "${host}" ] || return 0
    path="${rest#*/}"
    owner="${path%%/*}"
    repo="${path#*/}"
    [ -n "${owner}" ] || return 0
    [ "${path}" != "${owner}" ] || return 0
    [ -n "${repo}" ] || return 0
    case "$host" in
        github.com) printf 'ghcr.io/%s' "${owner}" ;;
        gitlab.com) printf 'registry.gitlab.com/%s' "${owner}" ;;
        *) printf '%s/%s' "${host}" "${owner}" ;;
    esac
}

provenance_setup() {
    GIT_SHA="unknown"
    GIT_REF="unknown"
    AUTHOR="unknown"
    SOURCE_URL=""
    REGISTRY="${REGISTRY:-}"
    VENDOR="unknown"
    BUILD_CREATED="unknown"

    if git rev-parse --git-dir >/dev/null 2>&1; then
        GIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
        GIT_REF="$(git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        AUTHOR="$(git log -1 --format='%an <%ae>' 2>/dev/null || echo unknown)"
        BUILD_CREATED="$(git show -s --format=%cI HEAD 2>/dev/null || echo unknown)"
        local remote="${BAKE_REMOTE:-}"
        if [ -z "${remote}" ]; then
            if git remote get-url origin >/dev/null 2>&1; then
                remote=origin
            else
                remote="$(git remote 2>/dev/null | head -n 1 || true)"
            fi
        fi
        if [ -n "${remote}" ]; then
            SOURCE_URL="$(normalize_remote "$(git remote get-url "${remote}" 2>/dev/null || true)")"
        fi
        if [ -z "${REGISTRY}" ] && [ -n "${SOURCE_URL}" ] && [ "${BAKE_DERIVE:-1}" != 0 ]; then
            REGISTRY="$(derive_registry "${SOURCE_URL}")"
        fi
        if [ -n "${AUTHOR}" ] && [ "${AUTHOR}" != unknown ] && [ "${VENDOR}" = unknown ]; then
            VENDOR="$(printf '%s' "${AUTHOR}" | sed -n 's/.*<[^@>]*@\([^>]*\)>.*/\1/p')"
            [ -n "${VENDOR}" ] || VENDOR=unknown
        fi
    fi

    export GIT_SHA GIT_REF AUTHOR SOURCE_URL REGISTRY VENDOR BUILD_CREATED
}
