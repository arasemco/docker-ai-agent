#!/bin/bash
# =============================================================================
# bake.sh — fills in docker-bake.hcl's provenance variables from the checkout
# and runs `docker buildx bake`.
#
# HCL cannot run git, read the remote or look at files, so every value that
# describes "who built this, from where, at which commit" would otherwise have
# to be typed by hand (or would render as "unknown" in the OCI labels). This
# wrapper derives them, then execs bake from the repo root so the bake file's
# relative `context = "image"` resolves.
#
# Derived (only when the variable is not already set in the environment):
#   GIT_SHA        git rev-parse HEAD
#   GIT_REF        exact tag if HEAD is tagged, else the branch name
#   AUTHOR         last commit author, "Name <email>"
#   SOURCE_URL     the git remote, normalised to an https URL without .git
#   REGISTRY       owner prefix derived from that remote:
#                    github.com/o/r      -> ghcr.io/o
#                    gitlab.com/o/r      -> registry.gitlab.com/o
#                    git.example/o/r     -> git.example/o
#
# The remote used for SOURCE_URL/REGISTRY is chosen in this order:
#   BAKE_REMOTE=<name>, then origin, then the first configured remote. A repo
#   whose only remote is called "gitea" or "upstream" therefore still derives
#   correctly; BAKE_REMOTE pins a specific one when there are several.
#   VENDOR         domain of the author's email (aram@asemo.pro -> asemo.pro)
#   LICENSES       SPDX id detected from LICENSE / LICENCE / COPYING
#   BASE_VERSION   the exact git tag at HEAD, when it looks like vX.Y.Z
#
# Rules:
#   * An environment variable always wins — `AUTHOR=... scripts/bake.sh --push`
#     beats anything derived here, and is how you publish under your identity.
#   * `BAKE_DERIVE=0` disables all derivation (leaves the bake defaults: no
#     registry, "unknown" metadata).
#   * `BAKE_QUIET=1` silences the one-line summary per derived value.
#   * `--push` without a derived or explicit REGISTRY is refused: bake would
#     otherwise tag the image as bare "agent-base" and try to push it to
#     Docker Hub (namespace "library"), which is never what anyone means.
#     `BAKE_ALLOW_DOCKERHUB_PUSH=1` is the explicit opt-in for that.
#   * Outside a git checkout (a source tarball) nothing is derived and bake
#     runs with its own defaults; there is no `git: command not found` noise.
#
# Usage (same arguments as bake):
#   scripts/bake.sh --print
#   scripts/bake.sh
#   scripts/bake.sh --push
#   scripts/bake.sh test
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

log() {
    [ "${BAKE_QUIET:-0}" = 1 ] || printf '[bake] %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Remote URL normalisation
# ---------------------------------------------------------------------------
# Accepts the forms a remote can take and returns a browser URL:
#   git@host:owner/repo.git            -> https://host/owner/repo
#   ssh://git@host:2222/owner/repo.git -> https://host:2222/owner/repo
#   https://user:token@host/owner/repo -> https://host/owner/repo
#   git://host/owner/repo.git          -> https://host/owner/repo
normalize_remote() {
    local url="$1"
    [ -n "$url" ] || return 0

    case "$url" in
        # scp-like syntax: [user@]host:path (no scheme)
        *://*) ;;
        *@*:*) url="ssh://${url%%:*}/${url#*:}" ;;
    esac

    # Drop any credentials embedded before the host.
    url="$(printf '%s' "$url" | sed -E 's#^([a-zA-Z][a-zA-Z0-9+.-]*://)[^/@]*@#\1#')"
    # Normalise the transport to https and drop ssh's implicit port.
    url="$(printf '%s' "$url" | sed -E 's#^(ssh|git)://#https://#; s#^https://([^/:]+):22/#https://\1/#')"
    # Strip a trailing .git and any trailing slash.
    url="${url%.git}"
    url="${url%/}"

    printf '%s' "$url"
}

# Registry prefix for an image built from this repo, derived from the origin
# URL's host and owner:  https://host/owner/repo -> host/owner. Known forges
# get their usual registry host instead of the git host.
#
# Needs at least two path segments (owner + repo): a single-segment remote like
# https://host/repo has no owner, so nothing is derived and the caller keeps the
# bake default (local tags).
derive_registry() {
    local url="$1" rest host path owner repo
    [ -n "$url" ] || return 0

    rest="${url#*://}"     # host[:port]/owner/repo
    host="${rest%%/*}"
    [ -n "${host}" ] || return 0
    path="${rest#*/}"      # owner/repo
    owner="${path%%/*}"
    repo="${path#*/}"

    [ -n "${owner}" ] || return 0
    [ "${path}" != "${owner}" ] || return 0   # no repo segment => no owner
    [ -n "${repo}" ] || return 0

    case "$host" in
        github.com) printf 'ghcr.io/%s' "${owner}" ;;
        gitlab.com) printf 'registry.gitlab.com/%s' "${owner}" ;;
        *) printf '%s/%s' "${host}" "${owner}" ;;
    esac
}

# ---------------------------------------------------------------------------
# Licence detection
# ---------------------------------------------------------------------------
# Deliberately a smoke test over the file's first lines rather than a full
# licence scanner: it only has to recognise the licences people actually drop
# in as LICENSE, and anything unrecognised keeps the bake default.
detect_license() {
    local f
    for f in LICENSE LICENSE.md LICENSE.txt LICENCE LICENCE.md COPYING; do
        [ -f "$f" ] || continue
        case "$f" in
            *COPYING*)
                if grep -qi "GNU GENERAL PUBLIC LICENSE" "$f"; then
                    grep -qi "Version 3" "$f" && printf 'GPL-3.0-only' || printf 'GPL-2.0-only'
                    return 0
                fi
                ;;
        esac
        if grep -qi "MIT License" "$f" \
            || grep -q "Permission is hereby granted, free of charge" "$f"; then
            printf 'MIT'
            return 0
        fi
        if grep -qi "Apache License" "$f"; then
            printf 'Apache-2.0'
            return 0
        fi
        if grep -qi "GNU GENERAL PUBLIC LICENSE" "$f"; then
            grep -qi "Version 3" "$f" && printf 'GPL-3.0-only' || printf 'GPL-2.0-only'
            return 0
        fi
        if grep -qi "BSD 3-Clause" "$f"; then
            printf 'BSD-3-Clause'
            return 0
        fi
        if grep -qi "ISC License" "$f" \
            || grep -q "Permission to use, copy, modify, and/or distribute this software" "$f"; then
            printf 'ISC'
            return 0
        fi
    done
}

# ---------------------------------------------------------------------------
# Derivation
# ---------------------------------------------------------------------------
in_git=0
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    in_git=1
fi

if [ "${BAKE_DERIVE:-1}" != 0 ] && [ "${in_git}" -eq 1 ]; then
    # SHA and ref always come from git when available: they describe the
    # checkout, not an identity, and a stale value would be worse than none.
    if [ -z "${GIT_SHA:-}" ]; then
        GIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
        log "GIT_SHA=${GIT_SHA}"
    fi
    if [ -z "${GIT_REF:-}" ]; then
        # A tagged HEAD is more useful in ref.name than "HEAD" (detached).
        GIT_REF="$(git describe --tags --exact-match 2>/dev/null \
            || git rev-parse --abbrev-ref HEAD 2>/dev/null \
            || echo unknown)"
        log "GIT_REF=${GIT_REF}"
    fi

    if [ -z "${AUTHOR:-}" ]; then
        AUTHOR="$(git log -1 --format='%an <%ae>' 2>/dev/null || true)"
        [ -n "${AUTHOR}" ] && log "AUTHOR=${AUTHOR} (last commit author)"
    fi

    if [ -z "${SOURCE_URL:-}" ]; then
        # origin if it exists, else whatever the first remote is called — a
        # repo whose only remote is "gitea"/"upstream" must still work.
        remote="${BAKE_REMOTE:-}"
        if [ -z "${remote}" ]; then
            if git remote get-url origin >/dev/null 2>&1; then
                remote=origin
            else
                remote="$(git remote 2>/dev/null | head -n 1 || true)"
            fi
        fi
        if [ -n "${remote}" ]; then
            SOURCE_URL="$(normalize_remote "$(git remote get-url "${remote}" 2>/dev/null || true)")"
            [ -n "${SOURCE_URL}" ] && log "SOURCE_URL=${SOURCE_URL} (remote '${remote}')"
        fi
    fi

    if [ -z "${REGISTRY:-}" ] && [ -n "${SOURCE_URL:-}" ]; then
        REGISTRY="$(derive_registry "${SOURCE_URL}")"
        [ -n "${REGISTRY}" ] && log "REGISTRY=${REGISTRY} (derived from the remote; override with REGISTRY=...)"
    fi

    # Vendor from the author's mail domain: a label, not a legal claim, so an
    # empty or non-domain value simply leaves the bake default in place.
    if [ -z "${VENDOR:-}" ] && [ -n "${AUTHOR:-}" ]; then
        VENDOR="$(printf '%s' "${AUTHOR}" | sed -n 's/.*<[^@>]*@\([^>]*\)>.*/\1/p')"
        [ -n "${VENDOR}" ] && log "VENDOR=${VENDOR} (author mail domain)"
    fi

    if [ -z "${LICENSES:-}" ]; then
        detected="$(detect_license)"
        if [ -n "${detected}" ]; then
            LICENSES="${detected}"
            log "LICENSES=${LICENSES} (from LICENSE file)"
        fi
    fi

    if [ -z "${BASE_VERSION:-}" ]; then
        tag="$(git describe --tags --exact-match 2>/dev/null || true)"
        case "${tag}" in
            v[0-9]*) BASE_VERSION="${tag#v}"; log "BASE_VERSION=${BASE_VERSION} (tag ${tag})" ;;
            [0-9]*) BASE_VERSION="${tag}"; log "BASE_VERSION=${BASE_VERSION} (tag ${tag})" ;;
        esac
    fi
fi

# Only export what we actually have: an unset variable leaves the HCL default
# ("unknown", or "" for REGISTRY/SOURCE_URL) untouched, because bake reads its
# variables from the environment when present.
for var in GIT_SHA GIT_REF AUTHOR SOURCE_URL REGISTRY VENDOR LICENSES BASE_VERSION; do
    if [ -n "${!var:-}" ]; then
        export "${var?}"
    fi
done

# ---------------------------------------------------------------------------
# Push guard
# ---------------------------------------------------------------------------
# `docker buildx bake --push` with an unprefixed tag pushes to Docker Hub under
# the "library" namespace, which fails with a confusing "denied: requested
# access to the resource is denied". Catch that before spending a build.
push_requested=0
for arg in "$@"; do
    case "${arg}" in
        --push) push_requested=1 ;;
        *push=true*) push_requested=1 ;;
    esac
done

if [ "${push_requested}" -eq 1 ]; then
    if [ -z "${REGISTRY:-}" ]; then
        if [ "${BAKE_ALLOW_DOCKERHUB_PUSH:-0}" != 1 ]; then
            cat >&2 <<'MSG'
[bake] ERROR: --push but no image registry is set, so bake would tag the image
[bake]        "agent-base:latest" and push it to Docker Hub under "library/",
[bake]        which is almost certainly not yours. Pick one:
[bake]
[bake]   REGISTRY=git.example.com/owner ./scripts/bake.sh --push
[bake]       set it explicitly (env wins over anything derived), or
[bake]   git remote add origin https://git.example.com/owner/repo.git
[bake]       let it derive <host>/<owner> from the remote, or
[bake]   BAKE_ALLOW_DOCKERHUB_PUSH=1 ./scripts/bake.sh --push
[bake]       really push to Docker Hub (you must be logged in as its owner)
MSG
            exit 1
        fi
        log "WARNING: pushing to Docker Hub under 'library/' (BAKE_ALLOW_DOCKERHUB_PUSH=1)"
    else
        log "pushing to ${REGISTRY} — log in first if you have not: docker login ${REGISTRY%%/*}"
        case "${REGISTRY}" in
            */*) ;;
            *) log "WARNING: REGISTRY='${REGISTRY}' has no namespace; the push target is ${REGISTRY}/agent-base" ;;
        esac
    fi
fi

exec docker buildx bake -f docker-bake.hcl "$@"
