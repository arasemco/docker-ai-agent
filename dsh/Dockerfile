# syntax=docker/dockerfile:1
# =============================================================================
# DeepSeek Harness (dsh) — Web UI container image
# =============================================================================
# Root is used only for package installation and user creation; dsh runs as
# a configurable unprivileged user (DSH_USER/DSH_UID/DSH_GID) from
# $HOME/workspace, with general dev tooling, Python 3, and a rootless Docker
# daemon (started by docker-entrypoint.sh) available to its shell commands.
#
# dsh is the npm package @deepseek-ai/dsh (upstream runs it with
# `npx @deepseek-ai/dsh web`), installed globally at a pinned version at
# build time, so the container starts without registry access.
#
# Base: Debian (glibc). dsh's plugin loader needs node-addon-require-builtin,
# which publishes only glibc prebuilt binaries; on a musl base such as
# Alpine, `dsh web` dies at boot with "--expose-internals is required for HMR
# service". Pinned by digest, passed in from docker-bake.hcl's NODE_BASE.
#
# SAFETY: dsh's web-app flag parser hard-refuses `--host 0.0.0.0` ("it
# would expose remote code execution to the network"; upstream SAFETY.md).
# The container binds loopback-only and never works around that guard; see
# docker-compose.yml for reaching the UI with `network_mode: host`.
ARG NODE_REF=docker.io/library/node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5

# =============================================================================
# runtime
# =============================================================================
FROM ${NODE_REF} AS runtime

# Exact @deepseek-ai/dsh version (`npm view @deepseek-ai/dsh versions`); a
# dist-tag would float. Minimum 0.1.5-rc.3: the npm build of 0.1.2-rc.1
# crashes on `dsh web` ("user patch-layer watching requires the Cordis HMR
# service").
ARG DSH_VERSION=0.1.5-rc.3

# Docker Engine version for the in-container rootless daemon, from Docker's
# Debian repo (`apt-cache madison docker-ce`).
ARG DOCKER_VERSION=29.8.1

# The node base image ships a "node" user at 1000:1000; relabel it to
# DSH_USER (keeping its home) rather than colliding with it, and only
# create a fresh user when the uid/gid is free. 1000 matches the first
# normal user on most hosts, so bind-mounted directories usually line up.
ARG DSH_USER=dsh
ARG DSH_UID=1000
ARG DSH_GID=1000

USER root

RUN existing_group="$(getent group "${DSH_GID}" | cut -d: -f1)" \
    && if [ -n "${existing_group}" ] && [ "${existing_group}" != "${DSH_USER}" ]; then \
        groupmod --new-name "${DSH_USER}" "${existing_group}"; \
    elif [ -z "${existing_group}" ]; then \
        groupadd --gid "${DSH_GID}" "${DSH_USER}"; \
    fi \
    && existing_user="$(getent passwd "${DSH_UID}" | cut -d: -f1)" \
    && if [ -n "${existing_user}" ] && [ "${existing_user}" != "${DSH_USER}" ]; then \
        usermod --login "${DSH_USER}" --gid "${DSH_GID}" --home "/home/${DSH_USER}" --move-home --shell /bin/bash "${existing_user}"; \
    elif [ -z "${existing_user}" ]; then \
        useradd --uid "${DSH_UID}" --gid "${DSH_GID}" --create-home --shell /bin/bash "${DSH_USER}"; \
    fi

# DSH_HOME (~/.dsh), the workspace, the rootless Docker data root
# (~/.local/share/docker), ~/.ssh and ~/.config (git identity/credentials,
# gh auth) are created here, owned by DSH_USER: Docker copies that
# ownership into a named volume on first mount, and the container has no
# root step left to fix it at runtime.
RUN mkdir -p "/home/${DSH_USER}/.dsh" "/home/${DSH_USER}/workspace" \
        "/home/${DSH_USER}/.local/share/docker" "/home/${DSH_USER}/.docker" \
        "/home/${DSH_USER}/.ssh" "/home/${DSH_USER}/.config" \
    && chmod 700 "/home/${DSH_USER}/.ssh" \
    && chown -R "${DSH_UID}:${DSH_GID}" "/home/${DSH_USER}"

# newuidmap/newgidmap look up subordinate ranges by user name; rootlesskit
# needs one for DSH_USER to map the uids of containers the daemon runs.
RUN grep -q "^${DSH_USER}:" /etc/subuid 2>/dev/null || echo "${DSH_USER}:100000:65536" >> /etc/subuid; \
    grep -q "^${DSH_USER}:" /etc/subgid 2>/dev/null || echo "${DSH_USER}:100000:65536" >> /etc/subgid

# General dev tooling for the shell commands the agent runs; nodejs/npm come
# with the base image. curl + ca-certificates also serve dsh's HTTPS model
# calls and the "test" stage's API check.
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        git \
        gh \
        gnupg \
        procps \
        nano \
        shellcheck \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Rootless Docker Engine: dockerd + CLI plugins pinned to DOCKER_VERSION,
# docker-ce-rootless-extras for dockerd-rootless.sh/rootlesskit, and the
# helpers it needs — uidmap (newuidmap/newgidmap), slirp4netns (user-mode
# networking), fuse-overlayfs (storage driver that works on top of the
# container's own overlay root), iptables and iproute2.
#
# Debian ships newuidmap/newgidmap setuid root, and in that mode their
# write to /proc/<pid>/uid_map is refused with EPERM inside a container,
# so rootlesskit can't set up its user namespace. Replace the setuid bit
# with just the capability each one needs (as Alpine's shadow-uidmap does).
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && docker_pkg="5:${DOCKER_VERSION}-1~debian.$(. /etc/os-release && echo "${VERSION_ID}")~$(. /etc/os-release && echo "${VERSION_CODENAME}")" \
    && apt-get install -y --no-install-recommends \
        "docker-ce=${docker_pkg}" \
        "docker-ce-cli=${docker_pkg}" \
        "docker-ce-rootless-extras=${docker_pkg}" \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        uidmap \
        slirp4netns \
        fuse-overlayfs \
        iptables \
        iproute2 \
        libcap2-bin \
    && rm -rf /var/lib/apt/lists/* \
    && chmod u-s /usr/bin/newuidmap /usr/bin/newgidmap \
    && setcap cap_setuid=ep /usr/bin/newuidmap \
    && setcap cap_setgid=ep /usr/bin/newgidmap

ENV UV_INSTALL_DIR=/usr/local/bin
RUN curl -fsSL https://astral.sh/uv/install.sh | sh

# Global install as root: /usr/local/lib/node_modules/@deepseek-ai/dsh, with
# /usr/local/bin/dsh linked to its lib/bin.js. No compiler needed, every
# native dependency ships prebuilt binaries. The npm cache stays in a
# BuildKit cache mount.
RUN --mount=type=cache,target=/root/.npm \
    npm install --global --no-fund --no-audit --no-update-notifier "@deepseek-ai/dsh@${DSH_VERSION}" \
    && dsh --version

# From here on — entrypoint, dsh, HEALTHCHECK, and `docker exec` by
# default — everything runs as DSH_USER, never root. HOME is set explicitly
# so code resolving defaults via os.homedir() never sees /root.
USER ${DSH_USER}
ENV HOME=/home/${DSH_USER} \
    NODE_ENV=production \
    UV_LINK_MODE=copy
ENV DSH_HOME=${HOME}/.dsh \
    DSH_WORKSPACE=${HOME}/workspace
# dockerd-rootless.sh only needs XDG_RUNTIME_DIR set and writable; it lives
# under $HOME because there is no systemd-managed /run/user/<uid>.
ENV XDG_RUNTIME_DIR=${HOME}/.docker/run \
    DOCKER_HOST=unix://${HOME}/.docker/run/docker.sock
WORKDIR ${HOME}/workspace

# Loopback-only by design (see SAFETY above); documents the port for
# `network_mode: host`, it publishes nothing on a bridge network.
EXPOSE 3080

# `GET /` is 401 without a signed-in browser session, so a plain curl can't
# pass. healthcheck.mjs loads dsh's stored session-signing secret from
# $DSH_HOME/.credentials.yaml, signs a short-lived cookie with it, and
# requires a 200.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --start-interval=5s --retries=3 \
    CMD ["node", "/usr/local/lib/dsh-healthcheck.mjs"]

COPY --chmod=644 healthcheck.mjs /usr/local/lib/dsh-healthcheck.mjs
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# No init baked in: dsh spawns tool subprocesses that need a real PID 1 to
# reap them, so run with `init: true` (compose) or `docker run --init`.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["web"]


# =============================================================================
# test — loads the real DeepSeek API key the same way the running container
# does and checks it works. Built only by the "test" target in
# docker-bake.hcl (`make test`); never pushed.
#
# dsh keeps the key in $DSH_HOME/.credentials.yaml under refs.DEEPSEEK_API_KEY
# (upstream packages/credentials/credentials-local: `version: 1` / `refs:` /
# `DEEPSEEK_API_KEY: sk-...`), which is what Settings → Models writes. That
# whole file comes in as the "dsh_credentials" BuildKit secret, mounted where
# dsh itself looks for it. A secret mount is never written into a layer.
#
# uid/gid 1000 (DSH_UID/DSH_GID's default — change both together) + mode
# 0600 on the mount are required: credentials-local refuses to read a
# credentials file with any group/other permission bit set.
# DEEPSEEK_API_KEY is deliberately NOT set in the environment. The inherited
# environment outranks the file, so setting it would skip the file load that
# this stage exists to test.
#
# Two checks:
#   1. GET https://api.deepseek.com/models with the key must return 200, so
#      the key itself is valid.
#   2. `dsh --profile headless` must finish a one-line task (exit 0), so dsh
#      really resolved the key from the file and completed a model round trip.
#
# DSH_HOME points at a scratch directory, not the image's ~/.dsh:
# the headless profile writes its profile/session files there on first use,
# and the secret mount inside it is read-only.
# =============================================================================
FROM runtime AS test

ENV DSH_HOME=/tmp/dsh-test/home
RUN install -d -m 700 /tmp/dsh-test/home /tmp/dsh-test/workspace
WORKDIR /tmp/dsh-test/workspace

RUN --mount=type=secret,id=dsh_credentials,target=/tmp/dsh-test/home/.credentials.yaml,uid=1000,gid=1000,mode=0600,required=true <<'EOF'
set -eu
creds="$DSH_HOME/.credentials.yaml"

key="$(awk '
  /^refs:/ { in_refs = 1; next }
  in_refs && /^[^ \t#]/ { in_refs = 0 }
  in_refs && $1 == "DEEPSEEK_API_KEY:" {
    v = $2; gsub(/^["\047]|["\047]$/, "", v); print v; exit
  }' "$creds")"
if [ -z "$key" ]; then
  echo "test: no refs.DEEPSEEK_API_KEY in the dsh_credentials secret" >&2
  exit 1
fi

# The header goes in on stdin, so the key never shows up in argv.
status="$(printf 'Authorization: Bearer %s\n' "$key" \
  | curl -sS -o /dev/null -w '%{http_code}' -H @- https://api.deepseek.com/models)"
unset key
if [ "$status" != 200 ]; then
  echo "test: DeepSeek API rejected the key (GET /models -> HTTP $status)" >&2
  exit 1
fi
echo "test: API key valid (GET /models -> 200)"

timeout 300 dsh --profile headless "Reply with exactly the word OK and nothing else." \
  > /tmp/dsh-test/answer
echo "test: dsh headless answered: $(cat /tmp/dsh-test/answer)"
grep -qi 'ok' /tmp/dsh-test/answer
EOF
