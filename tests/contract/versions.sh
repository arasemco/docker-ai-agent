#!/bin/bash
# The only place a pin may appear is versions.env (and generated docs).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"
fail=0
# Required keys.
# shellcheck disable=SC1091
. ./versions.env
for key in BASE_VERSION AGENT_CONTRACT DEBIAN_REF S6_OVERLAY_VERSION DOCKER_VERSION UV_VERSION NODE_REF OPENCODE_VERSION DSH_VERSION CLAUDE_VERSION; do
    [ -n "${!key:-}" ] || { echo "versions: missing ${key}" >&2; fail=1; }
done
# No digest or known pin literal outside versions.env.
if grep -rnE 'sha256:[0-9a-f]{64}|29\.8\.1|0\.13\.6|3\.2\.3\.0|1\.19\.5|2\.1\.316|0\.2\.2-rc\.1' \
    base stacks/*/image tooling docker-bake.hcl tables 2>/dev/null | grep -v 'versions.env'; then
    fail=1
fi
[ "$fail" -eq 0 ] && echo "versions OK"
exit "$fail"
