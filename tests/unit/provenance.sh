#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
. "${ROOT}/tooling/provenance.sh"
fail=0
eq() { [ "$1" = "$2" ] || { echo "unit: expected '$2', got '$1'" >&2; fail=1; }; }
eq "$(normalize_remote 'git@example.com:owner/repo.git')" 'https://example.com/owner/repo'
eq "$(normalize_remote 'ssh://git@example.com:2222/owner/repo.git')" 'https://example.com:2222/owner/repo'
eq "$(normalize_remote 'https://user:token@example.com/owner/repo.git')" 'https://example.com/owner/repo'
eq "$(derive_registry 'https://github.com/owner/repo')" 'ghcr.io/owner'
eq "$(derive_registry 'https://gitlab.com/owner/repo')" 'registry.gitlab.com/owner'
eq "$(derive_registry 'https://git.example.com/owner/repo')" 'git.example.com/owner'
[ "$fail" -eq 0 ] && echo "unit OK"
exit "$fail"
