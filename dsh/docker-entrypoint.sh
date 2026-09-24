#!/bin/bash
# Runs as the unprivileged DSH_USER (see the Dockerfile's USER), checks that
# DSH_HOME/DSH_WORKSPACE are writable, starts a rootless Docker daemon for
# the agent's `docker` commands, translates a small set of DSH_* env vars
# into `dsh web` flags, then hands off to dsh. Only touches argv for the
# default "web" mode; any other command (e.g. `docker run <image> --profile
# headless "task"`) is passed to dsh verbatim so every entry mode in
# apps/cli/README.md#entry-modes stays reachable.
#
# Ownership: the image creates DSH_HOME and DSH_WORKSPACE owned by DSH_USER,
# and Docker copies that into a named volume on first mount, so named
# volumes just work. A bind mount keeps its host ownership, and a source
# directory Docker auto-creates comes out root-owned. Without root this
# script can't chown it, so it stops with the fix instead of letting dsh fail
# later with EACCES.
#
# Recognized environment variables (all optional):
#   DSH_HOME           profiles/credentials/sessions root (image ENV: $HOME/.dsh)
#   DSH_WORKSPACE      directory dsh treats as its workspace root (image ENV: $HOME/workspace)
#   DSH_PORT           --port; 0 lets the OS pick a free one (default: dsh's own, 3080)
#   DSH_HOST           --host; REFUSED if "0.0.0.0" (see below)
#   DSH_TRUSTED_HOSTS  space-separated --trusted-host values (extra /api browser-trust authorities)
#   DSH_DOCKERD        set to 0 to skip starting the rootless Docker daemon (default: 1)
#
# Rootless Docker: the daemon runs as DSH_USER under rootlesskit, with its
# socket at $XDG_RUNTIME_DIR/docker.sock (DOCKER_HOST points there) and its
# log at ~/.docker/dockerd.log. It needs the container started with
# `security_opt: [seccomp:unconfined, systempaths=unconfined]` and the
# devices /dev/fuse and /dev/net/tun (see docker-compose.yml). Without them
# it exits early; this script logs that and still starts dsh.
set -e

log() {
    printf '[entrypoint] %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

: "${DSH_HOME:=$HOME/.dsh}"
: "${DSH_WORKSPACE:=$HOME/workspace}"
export DSH_HOME

log "user=$(id -un) HOME=$HOME DSH_HOME=$DSH_HOME DSH_WORKSPACE=$DSH_WORKSPACE"

for dir in "$DSH_HOME" "$DSH_WORKSPACE"; do
    mkdir -p "$dir" 2>/dev/null || true
    if [ ! -w "$dir" ]; then
        log "ERROR: $dir is not writable by $(id -un) (uid $(id -u), gid $(id -g))."
        log "This container runs as non-root and can't fix ownership itself. For a bind mount,"
        log "create the host directory before the first start, or: sudo chown -R $(id -u):$(id -g) <host path>"
        exit 1
    fi
done

start_dockerd() {
    local sock="$XDG_RUNTIME_DIR/docker.sock"
    local pidfile="$XDG_RUNTIME_DIR/docker.pid"
    local logfile="$HOME/.docker/dockerd.log"

    mkdir -p "$XDG_RUNTIME_DIR" "$HOME/.docker" "$HOME/.local/share/docker"
    chmod 0700 "$XDG_RUNTIME_DIR"

    if [ -S "$sock" ] && docker info >/dev/null 2>&1; then
        log "dockerd already running at $sock"
        return 0
    fi
    # A container restart keeps $HOME, so socket/pid state from the previous
    # boot can still be there with no daemon behind it.
    rm -rf "${XDG_RUNTIME_DIR:?}/docker" "$sock" "$pidfile" 2>/dev/null || true

    # fuse-overlayfs explicitly: native overlay2 can't be mounted on top of
    # the container's own overlay root filesystem.
    log "starting rootless dockerd (log: $logfile)"
    nohup dockerd-rootless.sh --storage-driver=fuse-overlayfs >>"$logfile" 2>&1 &
    local pid=$!

    local i
    for i in $(seq 1 30); do
        if [ -S "$sock" ] && docker info >/dev/null 2>&1; then
            log "dockerd ready after ${i}s"
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            log "WARNING: dockerd exited early; docker is unavailable. Last lines of $logfile:"
            tail -n 20 "$logfile" >&2 || true
            return 0
        fi
        sleep 1
    done
    log "WARNING: dockerd not ready after 30s; it keeps starting in the background (see $logfile)"
}

if [ "${DSH_DOCKERD:-1}" != 0 ]; then
    start_dockerd
fi

cd "$DSH_WORKSPACE"

if [ "${1:-}" = "web" ]; then
    shift
    set -- web --no-open "$@"

    if [ -n "${DSH_PORT:-}" ]; then
        set -- "$@" --port "$DSH_PORT"
    fi

    if [ -n "${DSH_HOST:-}" ]; then
        # dsh's own web-app flag parser refuses this too: "it would expose
        # remote code execution to the network; use 127.0.0.1 instead" (see
        # upstream SAFETY.md). Reach the UI from the host with
        # `network_mode: host` instead (see docker-compose.yml).
        if [ "$DSH_HOST" = "0.0.0.0" ]; then
            log "ERROR: refusing DSH_HOST=0.0.0.0 (exposes remote code execution; see upstream SAFETY.md)."
            log "Use network_mode: host and leave DSH_HOST unset; the UI then answers on http://localhost:<DSH_PORT>."
            exit 1
        fi
        set -- "$@" --host "$DSH_HOST"
    fi

    for host in ${DSH_TRUSTED_HOSTS:-}; do
        set -- "$@" --trusted-host "$host"
    done
fi

log "handing off to: dsh $*"
exec dsh "$@"
