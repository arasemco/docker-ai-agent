#!/bin/sh
# =============================================================================
# entrypoint.sh — runs as root (see dsh/Dockerfile: no USER instruction),
# fixes ownership of the mounted DSH_HOME/DSH_WORKSPACE directories, then
# drops to the unprivileged "dsh" user via setpriv before exec'ing dsh
# itself. Also translates a small set of DSH_* env vars into `dsh web`
# flags. Only touches argv when the invocation is the default "web" mode;
# any other command (e.g. `docker run <image> dsh --profile headless
# "task"`) is exec'd verbatim so every dsh entry mode in
# apps/cli/README.md#entry-modes stays reachable through this image.
#
# Why root-then-drop: docker-compose.yml bind-mounts host directories onto
# DSH_HOME and DSH_WORKSPACE (./data/dsh-home, ./data/workspace). A bind-mount
# source Docker has to auto-create because it doesn't exist yet comes out
# owned by root on the host — the "dsh" user (created at build time, see
# the Dockerfile) then has no write access, and dsh's app-boot code fails
# closed with EACCES the moment it tries to write into DSH_HOME/profiles at
# startup (verified — this is exactly what broke before this was added).
# There's no way to bake correct ownership into the image for a directory
# whose real content only shows up as a bind mount at `docker run` time, so
# this container starts as root specifically to fix it then, every start.
#
# Recognized environment variables (all optional):
#   DSH_HOME            profiles/credentials/sessions root (default: /home/dsh/.dsh,
#                        set as an image ENV — override only if you know why)
#   DSH_WORKSPACE        directory dsh treats as its workspace root (default: /workspace)
#   DSH_PORT              --port; pass 0 to let the OS pick a free one (default: dsh's own, 3080)
#   DSH_HOST              --host; REFUSED if "0.0.0.0" — see the SAFETY note below
#   DSH_TRUSTED_HOSTS    space-separated --trusted-host values (extra /api browser-trust authorities)
# =============================================================================
set -eu

: "${DSH_HOME:=/home/dsh/.dsh}"
: "${DSH_WORKSPACE:=/workspace}"
export DSH_HOME

# setpriv (below) only switches uid/gid — it does not touch the process
# environment, so without this HOME/USER/LOGNAME would still read "root"
# (whatever they were at container start) even after the process is
# running as "dsh". That stale HOME is exactly what caused
# `cannot list /root: EACCES` in practice: dsh/Node code resolving
# defaults via $HOME/os.homedir() (not $DSH_HOME) kept trying to open
# root's home directory, which the now-unprivileged "dsh" user can't
# read. Setting all three here is what a real login (`su -l`) would do
# for you — this is that "full init" step, done explicitly since
# setpriv doesn't do it implicitly.
export HOME=/home/dsh
export USER=dsh
export LOGNAME=dsh

if ! command -v setpriv >/dev/null 2>&1; then
  echo "entrypoint: setpriv not found — expected on the Debian base image (util-linux); can't safely drop from root to the dsh user" >&2
  exit 1
fi

# DSH_HOME is entirely container-managed (profiles/credentials/sessions) and
# normally small, so a recursive chown every start is cheap and safe. Its
# entries can also predate this fix (root-owned from an earlier run), so
# this always re-asserts ownership rather than skipping when it looks
# populated.
mkdir -p "$DSH_HOME"
chown -R dsh:dsh "$DSH_HOME"

# DSH_WORKSPACE is the user's own project — deliberately chowned
# non-recursively. Recursing here would rewrite ownership of every file the
# user already has outside the container just so dsh can create new ones
# inside it, which is more invasive than this needs to be; dsh itself runs
# as "dsh" and creates its own files with correct ownership from here on.
mkdir -p "$DSH_WORKSPACE"
chown dsh:dsh "$DSH_WORKSPACE"

cd "$DSH_WORKSPACE"

if [ "${1:-}" = "web" ]; then
  shift
  set -- web --no-open "$@"

  if [ -n "${DSH_PORT:-}" ]; then
    set -- "$@" --port "$DSH_PORT"
  fi

  if [ -n "${DSH_HOST:-}" ]; then
    if [ "$DSH_HOST" = "0.0.0.0" ]; then
      cat >&2 <<'EOF'
entrypoint: refusing DSH_HOST=0.0.0.0.

dsh's own web-app flag parser blocks this itself: "it would expose remote
code execution to the network; use 127.0.0.1 instead" (see upstream
SAFETY.md). This image does not work around that guard.

To reach the Web UI from the container's host, use `network_mode: host` in
docker-compose.yml (see that file's comments) and leave DSH_HOST unset —
the UI then answers on http://localhost:<DSH_PORT> exactly as if you had
run `dsh web` directly on the host, with the same loopback-only exposure
upstream intends.
EOF
      exit 1
    fi
    set -- "$@" --host "$DSH_HOST"
  fi

  for host in ${DSH_TRUSTED_HOSTS:-}; do
    set -- "$@" --trusted-host "$host"
  done
fi

# setpriv, not su/su-exec: execs straight into the target program with no
# intermediate shell, so it doesn't touch or reset the environment this
# script just built (DSH_HOME, PATH, the computed dsh argv) the way `su -`
# would. --init-groups reads dsh's supplementary groups from /etc/group so
# group-based file permissions behave as they would for a normally-started
# process, not just the bare --reuid/--regid identity switch.
exec setpriv --reuid=dsh --regid=dsh --init-groups dsh "$@"
