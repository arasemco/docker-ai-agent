#!/bin/bash
# PR gate: base/ changes require a BASE_VERSION bump; a stack image change
# requires that stack's CLI version bump. BASE_REF is the merge-base ref.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"
base_ref="${BASE_REF:-}"
if [ -z "${base_ref}" ]; then echo "version-bump: BASE_REF unset, skipped"; exit 0; fi
fail=0
old_version="$(git show "${base_ref}:versions.env" 2>/dev/null | sed -n 's/^BASE_VERSION=//p' | head -1 || true)"
old_contract="$(git show "${base_ref}:versions.env" 2>/dev/null | sed -n 's/^AGENT_CONTRACT=//p' | head -1 || true)"
# shellcheck disable=SC1091
. ./versions.env
if git diff --quiet "${base_ref}...HEAD" -- base/ 2>/dev/null; then :; else
    if [ -z "${old_version}" ] || [ "${BASE_VERSION}" = "${old_version}" ]; then
        echo "version-bump: base/ changed but BASE_VERSION is still ${BASE_VERSION}" >&2; fail=1
    fi
fi
if [ "${old_contract}" = "${AGENT_CONTRACT}" ]; then
for id in $(tooling/stacks.sh --list); do
    key="$(sed -n 's/^version_key: //p' "stacks/${id}/stack.yaml")"
    if ! git diff --quiet "${base_ref}...HEAD" -- "stacks/${id}/image/" 2>/dev/null; then
        old="$(git show "${base_ref}:versions.env" 2>/dev/null | sed -n "s/^${key}=//p" | head -1)"
        [ "${!key}" = "${old}" ] && { echo "version-bump: ${id} image changed but ${key} is still ${!key}" >&2; fail=1; }
    fi
done
fi
[ "$fail" -eq 0 ] && echo "version-bump OK"
exit "$fail"
