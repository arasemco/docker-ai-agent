#!/bin/bash
# =============================================================================
# compose.sh — assembles compose fragments and runs docker compose
# =============================================================================
# The compose/ directory holds one fragment per concern instead of one big
# file, so a stack includes exactly what it needs:
#
#   base.yml     always included: service skeleton, AGENT_* toggles, data volume
#   daemon.yml   devices + seccomp the rootless Docker daemon needs
#   proxy.yml    outbound proxy pass-through
#   limits.yml   CPU/memory limits
#   mounts.yml   bind the workspace to a host directory
#
# Usage:
#   scripts/compose.sh [--with daemon,proxy] [--service NAME] [--file F]... -- <compose args>
#
#   --with LIST     fragments to add beyond base.yml, comma separated
#                   (default: $COMPOSE_WITH, else "daemon")
#   --service NAME  compose service the fragments apply to (default: agent-base)
#   --fragments DIR where the fragments live (default: <repo>/compose)
#   --file FILE      extra compose file(s) to apply last, in order (a child
#                   stack passes its own docker-compose.yml; agent-base's own
#                   test stack uses compose/harness.yml)
#
# Examples:
#   scripts/compose.sh -- up -d --build                       # base + daemon
#   scripts/compose.sh --with daemon,proxy,mounts -- up -d     # + proxy + mounts
#   scripts/compose.sh --file compose/harness.yml -- config    # the test stack
#
# Why a script: `-f` merging only lines up services that share a NAME, and the
# fragments are written for the canonical service `agent-base`. When a child
# stack asks for another name (myagent, …) this renames the fragment's
# service key in a throwaway copy, so the child keeps its own service name and
# still gets the shared sandbox. `extends` cannot do that: compose accepts only
# a single extends per service, so it cannot stack fragments.
# =============================================================================
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

service="agent-base"
fragments_dir="${repo_root}/compose"
with_list="${COMPOSE_WITH:-daemon}"
extra_files=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --with) with_list="$2"; shift 2 ;;
        --with=*) with_list="${1#*=}"; shift ;;
        --service) service="$2"; shift 2 ;;
        --service=*) service="${1#*=}"; shift ;;
        --fragments) fragments_dir="$2"; shift 2 ;;
        --fragments=*) fragments_dir="${1#*=}"; shift ;;
        --file) extra_files+=("$2"); shift 2 ;;
        --file=*) extra_files+=("${1#*=}"); shift ;;
        --) shift; break ;;
        -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) break ;;
    esac
done

# base.yml first, then whatever was asked for, always in the same order so two
# fragments cannot override each other differently depending on the CLI order.
fragments=(base)
IFS=',' read -ra requested <<< "${with_list}"
for wanted in daemon proxy limits mounts; do
    for item in "${requested[@]}"; do
        [ "${item}" = "${wanted}" ] && fragments+=("${wanted}")
    done
done

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

compose_files=()
index=0
for fragment in "${fragments[@]}"; do
    file="${fragments_dir}/${fragment}.yml"
    if [ ! -f "${file}" ]; then
        printf '[compose] ERROR: no fragment %s (looked for %s)\n' "${fragment}" "${file}" >&2
        exit 1
    fi
    index=$((index + 1))
    if [ "${service}" = "agent-base" ]; then
        compose_files+=(-f "${file}")
        continue
    fi
    # Rename the canonical service key to the child's. The fragments declare it
    # at exactly one indent level, and nothing else in them starts with the
    # canonical name, so this stays predictable.
    renamed="${workdir}/$(printf '%02d' "${index}")-${fragment}.yml"
    sed "s/^  agent-base:/  ${service}:/" "${file}" > "${renamed}"
    compose_files+=(-f "${renamed}")
done

# Overlays are already written for the composing project's service name.
for file in "${extra_files[@]}"; do
    if [ ! -f "${file}" ]; then
        printf '[compose] ERROR: no such compose file: %s\n' "${file}" >&2
        exit 1
    fi
    compose_files+=(-f "${file}")
done

# Machine-specific overrides, when present.
if [ -f "${repo_root}/compose/local.yml" ]; then
    compose_files+=(-f "${repo_root}/compose/local.yml")
fi

# Compose resolves relative paths (build contexts, dockerfiles, bind sources)
# against the project directory, which it would otherwise infer from the first
# -f file. Anchor it to the directory of the stack file that was passed with
# --file: for a child stack that is its own repo root (so "context: ./image"
# means that repo's image/), for agent-base itself compose/image.yml (so its
# "../image" still points at the repo's image/).
if [ -n "${COMPOSE_PROJECT_DIR:-}" ]; then
    project_dir="${COMPOSE_PROJECT_DIR}"
elif [ "${#extra_files[@]}" -gt 0 ]; then
    project_dir="$(cd "$(dirname "${extra_files[0]}")" && pwd)"
else
    project_dir="$PWD"
fi

if [ "${COMPOSE_DEBUG:-0}" = 1 ]; then
    printf '[compose] docker compose --project-directory %s %s %s\n' \
        "${project_dir}" "${compose_files[*]}" "$*" >&2
fi

docker compose --project-directory "${project_dir}" "${compose_files[@]}" "$@"
