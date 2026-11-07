#!/bin/bash
# Discover and validate stack modules.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
list_ids() {
    for f in stacks/*/stack.yaml; do
        [ -f "$f" ] || continue
        basename "$(dirname "$f")"
    done
}
check_manifest() {
    local dir="$1"
    local id="$2"
    local f="stacks/$id/stack.yaml"
    local fail=0
    for item in "$f" "stacks/$id/image/Dockerfile" "stacks/$id/compose.yml" "stacks/$id/bake.hcl" "stacks/$id/test/probe.sh"; do
        [ -e "$item" ] || { echo "stacks: missing $item" >&2; fail=1; }
    done
    [ -d "stacks/$id/docs" ] || { echo "stacks: missing stacks/$id/docs" >&2; fail=1; }
    [ "$(basename "$dir")" = "$id" ] || { echo "stacks: id/dir mismatch in $dir" >&2; fail=1; }
    return "$fail"
}
case "${1:-}" in
    --list) list_ids ;;
    --profiles) printf 'base\n'; list_ids ;;
    --bake-targets) printf 'agent-base '; for id in $(list_ids); do printf '%s ' "$id"; done; echo ;;
    --check)
        fail=0
        for d in stacks/*/; do
            id="$(basename "$d")"
            grep -q "^id: ${id}$" "stacks/${id}/stack.yaml" 2>/dev/null || { echo "stacks: id missing/mismatched in ${id}" >&2; fail=1; }
            grep -q "^version_key: [A-Z_]*$" "stacks/${id}/stack.yaml" 2>/dev/null || { echo "stacks: version_key missing in ${id}" >&2; fail=1; }
            check_manifest "$d" "$id" || fail=1
        done
        [ -f base/stack.yaml ] || { echo "stacks: missing base/stack.yaml" >&2; fail=1; }
        exit "$fail" ;;
    *) echo "usage: $0 --list|--profiles|--bake-targets|--check" >&2; exit 2 ;;
esac
