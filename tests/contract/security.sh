#!/bin/bash
# Fail when the default opencode password can be published off-loopback, and
# require an explicit integrity decision for the npm CLIs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"
fail=0
if grep -Eq 'OPENCODE_SERVER_PASSWORD:-changeme123' stacks/opencode/compose.yml 2>/dev/null \
   && ! grep -q 'OPENCODE_BIND_IP:-127.0.0.1' stacks/opencode/compose.yml; then
    echo "security: opencode publishes a default password off-loopback" >&2; fail=1
fi
if ! grep -q '^# npm integrity:' config/knobs.env 2>/dev/null; then
    echo "security: record the npm install integrity decision in config/knobs.env" >&2; fail=1
fi
[ "$fail" -eq 0 ] && echo "security OK"
exit "$fail"
