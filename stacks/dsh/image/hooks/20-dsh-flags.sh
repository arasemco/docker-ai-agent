#!/bin/bash
# =============================================================================
# 20-dsh-flags.sh — translates DSH_* variables into `dsh web` options.
#
# Sourced by agent-run (see agent-base) before the CLI starts, in the workspace,
# as the agent user. It rewrites "$@" only for the default "web" mode; any other
# command — `--profile headless "task"`, `--help`, a shell — is passed through
# untouched, so every dsh entry mode stays reachable.
#
#   DSH_PORT           --port; 0 lets the OS pick a free port
#   DSH_HOST           --host; wildcard addresses are refused (see below)
#   DSH_TRUSTED_HOSTS  space-separated --trusted-host values
# =============================================================================

[ "${1:-}" = "web" ] || return 0

shift
set -- web --no-open "$@"

if [ -n "${DSH_PORT:-}" ]; then
    set -- "$@" --port "${DSH_PORT}"
fi

if [ -n "${DSH_HOST:-}" ]; then
    # dsh's own flag parser refuses every wildcard address, IPv6 included: it
    # would expose remote code execution to the network (upstream SAFETY.md).
    # Reach the UI from another machine with host networking, not with --host.
    case "${DSH_HOST}" in
        0.0.0.0|::|'[::]')
            printf '[hook] ERROR: refusing DSH_HOST=%s; use host networking and leave DSH_HOST unset\n' \
                "${DSH_HOST}" >&2
            exit 1
            ;;
    esac
    set -- "$@" --host "${DSH_HOST}"
fi

for host in ${DSH_TRUSTED_HOSTS:-}; do
    set -- "$@" --trusted-host "${host}"
done
