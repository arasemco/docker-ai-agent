#!/bin/bash
# =============================================================================
# selftest.sh — validates the agent-base image from inside a container.
#
#   selftest.sh              # tools + rootless dockerd + a storage-driver proof
#   selftest.sh --no-docker  # tools only (used by the Dockerfile "test" stage)
#
# Prints a PASS/FAIL table and exits non-zero if any check fails. The Dockerfile
# "test" stage runs the tool half; scripts/smoke.sh runs the full set inside a
# container that has the devices and seccomp profile the daemon needs.
# =============================================================================
set -uo pipefail

# The container's PID 1 user is now root (s6-overlay supervises root, and each
# service drops to AGENT_USER). Validation must run as the agent user, so
# re-exec through s6-setuidgid when invoked as root.
if [ "$(id -u)" = 0 ]; then
    if [ -x /command/s6-setuidgid ]; then
        exec /command/s6-setuidgid "${AGENT_USER:-agent}" "$0" "$@"
    fi
    echo "selftest: running as root and /command/s6-setuidgid is missing; refusing to validate a root environment" >&2
    exit 1
fi

want_docker=1
case "${1:-}" in
    --no-docker) want_docker=0 ;;
    "") ;;
    *) echo "usage: selftest.sh [--no-docker]" >&2; exit 2 ;;
esac

fails=0
pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }

echo "== identity"
if [ "$(id -u)" = 0 ]; then
    fail "running as root; the image must run as the agent user"
else
    pass "user $(id -un) (uid $(id -u), gid $(id -g))"
fi
if [ -w "$HOME" ]; then
    pass "HOME ($HOME) is writable"
else
    fail "HOME ($HOME) is not writable"
fi
workspace="${AGENT_WORKSPACE:-$HOME/workspace}"
if [ -w "$workspace" ]; then
    pass "workspace ($workspace) is writable"
else
    fail "workspace ($workspace) is not writable"
fi

echo "== tools"
# name:version-command. Every one of these is something an agent CLI or a tool
# it shells out to expects to find; a missing one is a real regression.
tools="bash:bash --version
curl:curl --version
git:git --version
gh:gh --version
jq:jq --version
make:make --version
node:node --version
npm:npm --version
python3:python3 --version
uv:uv --version
uvx:uvx --version
yq:yq --version
docker:docker --version
rg:rg --version
fd:fd --version
shellcheck:shellcheck --version
tmux:tmux -V
htop:htop --version
strace:strace -V
socat:socat -V
fuse-overlayfs:fuse-overlayfs --version"
while IFS=: read -r name cmd; do
    [ -z "$name" ] && continue
    if ! command -v "$name" >/dev/null 2>&1; then
        fail "$name is not installed"
        continue
    fi
    # shellcheck disable=SC2086 # cmd intentionally word-split
    version="$($cmd 2>&1 | head -n 1)"
    pass "$name ($version)"
done <<<"$tools"

echo "== python venv"
if python3 -m venv /tmp/selftest-venv >/dev/null 2>&1 \
    && /tmp/selftest-venv/bin/python -c 'import sys; assert sys.prefix != sys.base_prefix' 2>/dev/null; then
    pass "python3 -m venv works"
else
    fail "python3 -m venv is broken (python3-venv missing?)"
fi
rm -rf /tmp/selftest-venv

echo "== rootless docker"
if [ "$want_docker" = 0 ]; then
    echo "  skip  (--no-docker)"
else
    if timeout 15 docker info >/dev/null 2>&1; then
        driver="$(docker info --format '{{.Driver}}' 2>/dev/null)"
        server="$(docker info --format '{{.ServerVersion}}' 2>/dev/null)"
        pass "daemon $server responds"
        if [ "$driver" = fuse-overlayfs ]; then
            pass "storage driver $driver"
        else
            fail "storage driver is '$driver', expected fuse-overlayfs"
        fi
        # Offline proof that the daemon can actually build and store a layer:
        # FROM scratch needs no registry and no network.
        if printf 'FROM scratch\nLABEL selftest=agent-base\n' \
            | timeout 60 docker build -q -t agent-base-selftest - >/dev/null 2>&1; then
            pass "docker build (FROM scratch) works"
            docker rmi -f agent-base-selftest >/dev/null 2>&1 || true
        else
            fail "docker build (FROM scratch) failed"
        fi
    else
        fail "rootless dockerd is not responding (log: ${HOME}/.docker/dockerd.log)"
        tail -n 20 "${HOME}/.docker/dockerd.log" 2>/dev/null | sed 's/^/        /' || true
    fi
fi

echo
if [ "$fails" -ne 0 ]; then
    echo "FAILED: $fails check(s)"
    exit 1
fi
echo "PASSED"
