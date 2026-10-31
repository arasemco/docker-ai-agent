# syntax=docker/dockerfile:1
# =============================================================================
# agent-base — shared sandbox image for AI coding-agent CLIs
# =============================================================================
# Everything the claude-code, opencode and deepseek-harness images used to
# repeat is defined once here:
#
#   * Debian 12 (glibc), pinned by digest, with Node/npm from Debian's own
#     packages. Not Alpine: several agent CLIs ship glibc-only prebuilt native
#     modules (dsh dies at boot on musl with "--expose-internals is required
#     for the HMR service"), so glibc is the only base all three run on.
#     NOTE: bookworm's nodejs is 18.20 — fine for npm tooling, too old for dsh,
#     whose package.json engines require ^22.19.0 || >=24. A child that needs a
#     newer Node must supply it itself (NodeSource apt repo, pinned tarball, or
#     the upstream node image); this base installs only from package managers.
#   * One unprivileged user (AGENT_USER, uid/gid 1000 by default) that owns
#     everything under its home, so bind mounts line up with the host user
#     on most systems.
#   * A rootless Docker daemon (docker-ce + rootless extras) started by
#     agent-entrypoint, so the agent can run `docker` without --privileged.
#   * Python 3 + uv, Node/npm, yq, git/gh, a native build toolchain and the
#     GNU userland tools agents expect to exist — all from a package manager.
#   * The generic agent-entrypoint (hook system + dockerd bootstrap) and
#     agent-healthcheck.
#
# Agent-specific parts do NOT belong here — installing the CLI, its config
# and defaults go in the child image:
#
#     FROM git.omesa.net/asemo/agent-base:1
#     ARG CLAUDE_VERSION=2.1.3
#     RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "${CLAUDE_VERSION}"
#     ENV AGENT_CMD=claude
#     COPY hooks/ /etc/agent-entrypoint.d/
# =============================================================================

ARG DEBIAN_REF=docker.io/library/debian:bookworm-slim@sha256:99c0b25c46d0214d5a2091092e7908907dcaecd6a962cde0ac700acee222b6f3

FROM ${DEBIAN_REF} AS agent-base

# AGENT_USER names the unprivileged account that runs the agent. Bare Debian
# has nothing at uid/gid 1000, so the account is created fresh here; the
# relabel branch exists for bases that already ship one (the node image used
# to, as "node"). Every path in compose.base.yml follows ${AGENT_USER}.
ARG AGENT_USER=agent
ARG AGENT_UID=1000
ARG AGENT_GID=1000

# Docker Engine version for the in-container rootless daemon, from Docker's
# Debian repo (`apt-cache madison docker-ce`).
ARG DOCKER_VERSION=29.8.1

# uv (Python toolchain), installed from PyPI at this exact version.
ARG UV_VERSION=0.13.6

USER root

RUN existing_group="$(getent group "${AGENT_GID}" | cut -d: -f1)" \
    && if [ -n "${existing_group}" ] && [ "${existing_group}" != "${AGENT_USER}" ]; then \
        groupmod --new-name "${AGENT_USER}" "${existing_group}"; \
    elif [ -z "${existing_group}" ]; then \
        groupadd --gid "${AGENT_GID}" "${AGENT_USER}"; \
    fi \
    && existing_user="$(getent passwd "${AGENT_UID}" | cut -d: -f1)" \
    && if [ -n "${existing_user}" ] && [ "${existing_user}" != "${AGENT_USER}" ]; then \
        usermod --login "${AGENT_USER}" --gid "${AGENT_GID}" --home "/home/${AGENT_USER}" --move-home --shell /bin/bash "${existing_user}"; \
    elif [ -z "${existing_user}" ]; then \
        useradd --uid "${AGENT_UID}" --gid "${AGENT_GID}" --create-home --shell /bin/bash "${AGENT_USER}"; \
    fi

# Directories every agent image needs, created (and owned) here so a named
# volume mounted on any of them inherits the agent user's ownership on first
# use instead of coming up root-owned:
#   ~/Projects                 AGENT_WORKSPACE, the agent's working directory
#   ~/.local/share/docker      rootless daemon data root (named volume)
#   ~/.docker                  daemon log + XDG_RUNTIME_DIR
#   ~/.local/bin, ~/.config    CLI installers (claude, opencode) and XDG config
#   ~/.ssh, ~/.gitconfig       git identity/credentials, gh auth
#   /etc/agent-entrypoint.d    sourced hooks (child images COPY into it)
RUN mkdir -p "/home/${AGENT_USER}/Projects" \
        "/home/${AGENT_USER}/.local/share/docker" \
        "/home/${AGENT_USER}/.local/bin" \
        "/home/${AGENT_USER}/.local/state" \
        "/home/${AGENT_USER}/.docker" \
        "/home/${AGENT_USER}/.ssh" \
        "/home/${AGENT_USER}/.config" \
        "/home/${AGENT_USER}/.cache" \
        "/etc/agent-entrypoint.d" \
    && chmod 700 "/home/${AGENT_USER}/.ssh" \
    && chown -R "${AGENT_UID}:${AGENT_GID}" "/home/${AGENT_USER}"

# newuidmap/newgidmap resolve subordinate ranges by user name; rootlesskit
# needs a range for AGENT_USER to map the uids of the containers it starts.
RUN grep -q "^${AGENT_USER}:" /etc/subuid 2>/dev/null || echo "${AGENT_USER}:100000:65536" >> /etc/subuid; \
    grep -q "^${AGENT_USER}:" /etc/subgid 2>/dev/null || echo "${AGENT_USER}:100000:65536" >> /etc/subgid

# Base tooling for the shell commands an agent runs. nodejs/npm come from
# Debian (18.20 / npm 9.2 on bookworm — see the header note about dsh needing
# >= 22.19); curl + ca-certificates also serve HTTPS model calls.
#
# yq is the Debian package: kislyuk's 3.x, a jq wrapper (jq syntax, `yq -y` for
# YAML output). mikefarah's Go yq v4 is not in Debian and would need a GitHub
# release download, which this image deliberately avoids — everything
# userland-facing comes from apt. The two yq implementations are not drop-in
# compatible; anything needing v4 syntax must install it itself. (This build
# prints `yq --version` as "yq 0.0.0" while dpkg has 3.1.0-3: an upstream
# packaging quirk, not a broken install.)
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        wget \
        jq \
        yq \
        rsync \
        git \
        gh \
        gnupg \
        openssh-client \
        procps \
        nano \
        make \
        shellcheck \
        python3 \
        python3-pip \
        python3-venv \
        pipx \
        nodejs \
        npm \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Native build toolchain: agents routinely install PyPI/npm packages whose
# wheels are missing for the platform (e.g. scikit-learn), so keep the
# compilers and build systems those source builds need.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        linux-libc-dev \
        python3-dev \
        cmake \
        meson \
        ninja-build \
        pkg-config \
        patch \
        libffi-dev \
        libssl-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Everyday CLI utilities. Debian's GNU userland already covers what Alpine's
# BusyBox gaps needed; these are the extras the agent images shipped. fd-find
# installs its binary as `fdfind`, so link it to `fd`.
RUN apt-get update && apt-get install -y --no-install-recommends \
        coreutils \
        findutils \
        grep \
        sed \
        gawk \
        diffutils \
        less \
        file \
        tree \
        ripgrep \
        fd-find \
        tmux \
        htop \
        strace \
        lsof \
        dnsutils \
        zip \
        xz-utils \
        zstd \
        sqlite3 \
        gettext-base \
        socat \
        iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

# uv comes from PyPI at a pinned version, installed by pipx — itself an apt
# package. Debian has no `uv` package in any suite (checked bookworm, trixie
# and sid), and PyPI is the only package-managed source, so this replaces the
# official `curl astral.sh | sh` installer. PIPX_HOME/PIPX_BIN_DIR keep pipx's
# venv out of a user's home, so `uv` and `uvx` land in /usr/local/bin for the
# agent user instead of root's ~/.local/bin.
ENV UV_LINK_MODE=copy
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin \
    pipx install "uv==${UV_VERSION}" \
    && uv --version \
    && uvx --version

# Rootless Docker Engine: dockerd + CLI plugins pinned to DOCKER_VERSION,
# docker-ce-rootless-extras for dockerd-rootless.sh/rootlesskit, plus the
# helpers it needs — uidmap (newuidmap/newgidmap), slirp4netns (user-mode
# networking), fuse-overlayfs (the storage driver that works on top of the
# container's own overlay root), iptables and iproute2.
#
# Debian ships newuidmap/newgidmap setuid root; inside a container that setuid
# bit makes their write to /proc/<pid>/uid_map fail with EPERM, so rootlesskit
# can't set up its user namespace. Replace it with just the capability each
# binary needs.
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
        libcap2-bin \
    && rm -rf /var/lib/apt/lists/* \
    && chmod u-s /usr/bin/newuidmap /usr/bin/newgidmap \
    && setcap cap_setuid=ep /usr/bin/newuidmap \
    && setcap cap_setgid=ep /usr/bin/newgidmap

# From here on — the entrypoint, the agent CLI, HEALTHCHECK and `docker exec`
# by default — everything runs as AGENT_USER, never root. HOME is explicit so
# anything resolving os.homedir() never sees /root.
USER ${AGENT_UID}:${AGENT_GID}
ENV HOME=/home/${AGENT_USER} \
    NODE_ENV=production \
    AGENT_USER=${AGENT_USER}
ENV AGENT_WORKSPACE=${HOME}/Projects \
    AGENT_DOCKERD=1 \
    AGENT_DOCKERD_TIMEOUT=30 \
    AGENT_CMD=bash \
    AGENT_HEALTHCHECK=auto
# dockerd-rootless.sh only needs XDG_RUNTIME_DIR set and writable; it lives
# under $HOME because there is no systemd-managed /run/user/<uid> here.
ENV XDG_RUNTIME_DIR=${HOME}/.docker/run \
    DOCKER_HOST=unix://${HOME}/.docker/run/docker.sock
WORKDIR ${HOME}/Projects

COPY --chmod=755 rootfs/usr/local/bin/agent-entrypoint /usr/local/bin/agent-entrypoint
COPY --chmod=755 rootfs/usr/local/bin/agent-healthcheck /usr/local/bin/agent-healthcheck
COPY --chmod=755 rootfs/usr/local/lib/agent-base/selftest.sh /usr/local/lib/agent-base/selftest.sh
COPY --chmod=644 rootfs/etc/agent-entrypoint.d/README /etc/agent-entrypoint.d/README

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --start-interval=5s --retries=3 \
    CMD ["/usr/local/bin/agent-healthcheck"]

# No init baked in: agents spawn tool subprocesses that need a real PID 1 to
# reap them and forward signals, so run with `init: true` (compose) or
# `docker run --init` (compose.base.yml sets it).
ENTRYPOINT ["/usr/local/bin/agent-entrypoint"]
CMD []


# =============================================================================
# test — build-time checks that need no daemon: the user exists with the
# requested uid/gid, the tool matrix resolves and runs, and both scripts pass
# shellcheck. Built by the "test" bake target and by `make test`; never pushed.
# The runtime checks (dockerd, storage driver) need the container's devices and
# seccomp profile, so they live in scripts/smoke.sh instead.
# =============================================================================
FROM agent-base AS test

ARG AGENT_USER=agent
ARG AGENT_UID=1000
ARG AGENT_GID=1000

USER root
RUN apt-get update && apt-get install -y --no-install-recommends shellcheck \
    && rm -rf /var/lib/apt/lists/* \
    && shellcheck /usr/local/bin/agent-entrypoint /usr/local/bin/agent-healthcheck \
        /usr/local/lib/agent-base/selftest.sh

USER ${AGENT_UID}:${AGENT_GID}
RUN /usr/local/lib/agent-base/selftest.sh --no-docker
