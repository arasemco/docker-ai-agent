#!/bin/bash
# Shared helpers for the agent-base scripts. Sourced, never executed.
#   . /usr/local/lib/agent-base/lib.sh
# shellcheck shell=bash

log() {
    printf '[%s] %s %s\n' "${AGENT_LOG_TAG:-agent}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

agent_uid() {
    id -u "${AGENT_USER:-agent}" 2>/dev/null
}

agent_gid() {
    id -g "${AGENT_USER:-agent}" 2>/dev/null
}

agent_home() {
    getent passwd "${AGENT_USER:-agent}" 2>/dev/null | cut -d: -f6
}

state_get() {
    cat "$1" 2>/dev/null || printf '%s' "${2:-0}"
}

state_set() {
    mkdir -p "$(dirname "$1")" 2>/dev/null || true
    printf '%s\n' "$2" > "$1" 2>/dev/null || true
}

state_clear() {
    rm -f "$1" 2>/dev/null || true
}
