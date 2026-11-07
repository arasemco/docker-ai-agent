#!/bin/bash
set -euo pipefail
docker compose --profile claude exec --no-TTY --user 1000 claude claude --version
docker compose --profile claude exec --no-TTY --user 1000 claude claude auth status --text 2>&1 || true
