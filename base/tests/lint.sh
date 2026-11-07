#!/bin/bash
# Lint every shell file in the image, discovered rather than listed.
set -euo pipefail
mapfile -t files < <(find /usr/local/bin /usr/local/lib/agent-base /etc/cont-init.d /etc/services.d \
    -type f \( -name '*.sh' -o -name run -o -name finish \) | sort)
shellcheck -s bash -e SC1008 -- "${files[@]}"
echo "lint OK: ${#files[@]} files"
