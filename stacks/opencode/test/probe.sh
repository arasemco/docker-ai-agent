#!/bin/bash
# OpenCode runtime probe. Runs on the host with versions exported.
set -euo pipefail
port="${OPENCODE_PORT:-4096}"
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${port}/" || true)"
case "${code}" in ""|000) echo "opencode: no response on ${port}" >&2; exit 1 ;; esac
docker compose --profile opencode exec --no-TTY opencode opencode --version
