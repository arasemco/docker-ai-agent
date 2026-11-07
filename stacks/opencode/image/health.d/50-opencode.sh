#!/bin/bash
# The UI answers 401 before sign-in; 000 means nothing is listening.
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 "http://127.0.0.1:${OPENCODE_PORT:-4096}/" 2>/dev/null || true)"
case "${code}" in
    2*|3*|401) exit 0 ;;
    *) printf 'opencode healthcheck: HTTP %s\n' "${code:-000}" >&2; exit 1 ;;
esac
