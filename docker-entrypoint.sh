#!/bin/bash
set -e

log() {
    printf '[entrypoint] %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.docker/run}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

DOCKER_SOCK="${XDG_RUNTIME_DIR}/docker.sock"
DOCKER_PID="${XDG_RUNTIME_DIR}/docker.pid"
DOCKER_LOG="$HOME/.docker/dockerd.log"

log "HOME=$HOME XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR DOCKER_SOCK=$DOCKER_SOCK"

cleanup_runtime_state() {
    log "removing docker runtime socket/pid state at $XDG_RUNTIME_DIR"
    rm -rf "${XDG_RUNTIME_DIR:?}/docker" "$DOCKER_SOCK" "$DOCKER_PID" 2>/dev/null || true
}
trap cleanup_runtime_state EXIT

if [ -S "$DOCKER_SOCK" ] && docker info >/dev/null 2>&1; then
    log "dockerd already running and responsive at $DOCKER_SOCK, skipping start"
else
    if [ -S "$DOCKER_SOCK" ]; then
        log "found stale socket at $DOCKER_SOCK, resetting"
        rm -f "$DOCKER_SOCK"
    fi
    if [ -e "$DOCKER_PID" ] || [ -d "${XDG_RUNTIME_DIR}/docker" ]; then
        log "clearing docker runtime state left over from a previous container boot"
        rm -rf "${XDG_RUNTIME_DIR:?}/docker" "$DOCKER_PID" 2>/dev/null || true
    fi

    mkdir -p "$HOME/.local/share/docker" "$HOME/.docker"
    log "starting dockerd-entrypoint.sh dockerd"
    nohup dockerd-entrypoint.sh dockerd --storage-driver=fuse-overlayfs >>"$DOCKER_LOG" 2>&1 &
    dockerd_bg_pid=$!

    ready=0
    for i in $(seq 1 30); do
        if [ -S "$DOCKER_SOCK" ] && docker info >/dev/null 2>&1; then
            log "dockerd ready after ${i}s"
            ready=1
            break
        fi
        if ! kill -0 "$dockerd_bg_pid" 2>/dev/null; then
            log "ERROR: dockerd exited early; check $DOCKER_LOG"
            break
        fi
        sleep 1
    done

    if [ "$ready" -ne 1 ]; then
        log "WARNING: dockerd did not report ready in time"
    fi
fi

log "handing off to: opencode $*"
exec opencode "$@"
