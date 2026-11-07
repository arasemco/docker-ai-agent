#!/bin/bash
# Base contract assertions, run inside the test stage and by every stack test.
set -euo pipefail
contract_dir="${1:-/}"
fail=0
check() { if [ -e "$1" ]; then echo "contract: ok $1"; else echo "contract: MISSING $1" >&2; fail=1; fi; }
check "${contract_dir}/etc/agent-launch.d/agent.sh"
check "${contract_dir}/etc/agent-healthcheck.d"
check "${contract_dir}/etc/agent-state.d"
check "${contract_dir}/usr/local/lib/agent-base/lib.sh"
check "${contract_dir}/usr/local/bin/agent-run"
check "${contract_dir}/usr/local/bin/agent-service-start"
check "${contract_dir}/etc/services.d/agent/run"
if [ -f "${contract_dir}/CONTRACT" ]; then
    grep -Eq '^[0-9]+$' "${contract_dir}/CONTRACT" || { echo "contract: bad CONTRACT" >&2; fail=1; }
fi
# The launch file must set a non-empty AGENT_LAUNCH array.
# shellcheck disable=SC1091
( . "${contract_dir}/etc/agent-launch.d/agent.sh" && [ "${#AGENT_LAUNCH[@]}" -gt 0 ] ) \
    || { echo "contract: launch file sets no AGENT_LAUNCH" >&2; fail=1; }
exit "$fail"
