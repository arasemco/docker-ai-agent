# syntax=docker/dockerfile:1
# =============================================================================
# agent-base — shared sandbox image for AI coding-agent CLIs
# =============================================================================
# Everything an agent image needs is defined once here, so child images carry
# only their own CLI:
#
#   * Debian 12 (glibc), pinned by digest, with Node/npm from Debian's own
#     packages. Not Alpine: agent CLIs commonly ship glibc-only prebuilt native
#     modules (Node's native addons and several standalone binaries fail on
#     musl), so glibc is the portable choice.
#     NOTE: bookworm's nodejs is 18.20. Packaging that is fine, but a CLI whose
#     package.json engines demand a newer Node must install its own (NodeSource
#     apt repo, pinned tarball, or the upstream node image); this base installs
#     only from package managers.
#   * One unprivileged user (AGENT_USER, uid/gid 1000 by default) that owns
#     everything under its home, so bind mounts line up with the host user
#     on most systems.
#   * s6-overlay as PID 1, supervising two independent longruns:
#       - dockerd: the rootless Docker daemon (docker-ce + rootless extras),
#         so the agent can run `docker` without --privileged, restarted on
#         crash and announcing readiness through s6's notification fd;
#       - agent: the CLI itself, run as AGENT_USER, restarted on crash up to a
#         limit, and stopping the container when it exits cleanly.
#     Splitting them is the point: a crashing daemon no longer takes the
#     agent down with it, and a dead agent no longer hides behind a live
#     daemon. Hooks still run before the CLI starts (services.d/agent/run).
#   * Python 3 + uv, Node/npm, yq, git/gh, a native build toolchain and the
#     GNU userland tools agents expect to exist — all from a package manager.
#   * A generic entrypoint wrapper (passes docker CMD args to the agent
#     service, then execs s6's /init) and agent-healthcheck.
#
# Agent-specific parts do NOT belong here — installing the CLI, its config
# and defaults go in the child image (see ../examples/child-image/):
#
#     FROM agent-base:1.2.0
#     ARG CLI_VERSION=1.0.0
#     RUN npm install --global "some-agent-cli@${CLI_VERSION}"
#     ENV AGENT_CMD=some-agent-cli
#     COPY hooks/ /etc/agent-entrypoint.d/
# =============================================================================

ARG DEBIAN_REF=docker.io/library/debian:bookworm-slim@sha256:99c0b25c46d0214d5a2091092e7908907dcaecd6a962cde0ac700acee222b6f3

# s6-overlay release and the sha256 of each release asset, pinned rather than
# tracked as "latest".
# The digests live here, not next to the tarballs, so a tampered release
# asset fails the build instead of being checked against an equally tampered
# .sha256 file. Bump by checking
# https://github.com/just-containers/s6-overlay/releases.
ARG S6_OVERLAY_VERSION=3.2.3.0
ARG S6_SHA256_NOARCH=b720f9d9340efc8bb07528b9743813c836e4b02f8693d90241f047998b4c53cf
ARG S6_SHA256_X86_64=a93f02882c6ed46b21e7adb5c0add86154f01236c93cd82c7d682722e8840563
ARG S6_SHA256_AARCH64=0952056ff913482163cc30e35b2e944b507ba1025d78f5becbb89367bf344581

# =============================================================================
# s6 — fetch, verify and extract s6-overlay in its own stage, so bumping
# S6_OVERLAY_VERSION doesn't invalidate the apt layers and vice versa. The
# extracted tree (its contents land at /) is copied wholesale below.
#
# The noarch tarball is fetched with ADD --checksum (same file on every arch);
# the arch-specific one needs a shell case on TARGETARCH, so it uses curl +
# sha256sum -c. Remote tar sources are not auto-extracted by ADD, hence the
# explicit tar -Jxpf.
# =============================================================================
FROM ${DEBIAN_REF} AS s6

ARG S6_OVERLAY_VERSION
ARG S6_SHA256_NOARCH
ARG S6_SHA256_X86_64
ARG S6_SHA256_AARCH64

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

ADD --checksum=sha256:${S6_SHA256_NOARCH} https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/

ARG TARGETARCH
RUN set -eu; \
    case "${TARGETARCH}" in \
        amd64) S6_ARCH=x86_64;  S6_SHA256="${S6_SHA256_X86_64}" ;; \
        arm64) S6_ARCH=aarch64; S6_SHA256="${S6_SHA256_AARCH64}" ;; \
        *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    cd /tmp && \
    curl -fsSLO "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" && \
    echo "${S6_SHA256}  s6-overlay-${S6_ARCH}.tar.xz" | sha256sum -c - && \
    mkdir -p /s6-root && \
    tar -C /s6-root -Jxpf "s6-overlay-noarch.tar.xz" && \
    tar -C /s6-root -Jxpf "s6-overlay-${S6_ARCH}.tar.xz" && \
    rm -f /tmp/*.tar.xz


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
#   ~/workspace                AGENT_WORKSPACE, the agent's working directory
#   ~/.local/share/docker      rootless daemon data root (named volume)
#   ~/.docker                  daemon log + XDG_RUNTIME_DIR
#   ~/.local/bin, ~/.config    CLI installers and XDG config
#   ~/.ssh, ~/.gitconfig       git identity/credentials, gh auth
#   /etc/agent-entrypoint.d    sourced hooks (child images COPY into it)
RUN mkdir -p "/home/${AGENT_USER}/workspace" \
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
# Debian (18.20 / npm 9.2 on bookworm — see the header note about CLIs
# that need a newer Node); curl + ca-certificates also serve HTTPS model calls.
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

# s6-overlay: /init (PID 1) supervises the services below, reaps orphans and
# forwards signals. s6, s6-rc and the helper binaries live in /command, which
# is not on PATH — service scripts use the absolute /command/... paths or the
# #!/command/with-contenv shebang.
COPY --from=s6 /s6-root /

# The container itself now runs as root (PID 1 must be /init to create /run
# state, chown mount points and drop privileges per service); the agent CLI
# and the Docker daemon both run as AGENT_USER, dropped by s6-setuidgid in
# each service's run script. HOME is explicit so anything resolving
# os.homedir() never sees /root.
ENV HOME=/home/${AGENT_USER} \
    NODE_ENV=production \
    AGENT_USER=${AGENT_USER} \
    AGENT_UID=${AGENT_UID}

ENV AGENT_WORKSPACE=${HOME}/workspace \
    AGENT_DOCKERD=1 \
    AGENT_DOCKERD_TIMEOUT=30 \
    AGENT_DOCKERD_MAX_RESTARTS=3 \
    AGENT_RESTART_MAX=3 \
    AGENT_CMD=bash \
    AGENT_HEALTHCHECK=auto
# dockerd-rootless.sh only needs XDG_RUNTIME_DIR set and writable; it lives
# under $HOME because there is no systemd-managed /run/user/<uid> here.
ENV XDG_RUNTIME_DIR=${HOME}/.docker/run \
    DOCKER_HOST=unix://${HOME}/.docker/run/docker.sock
WORKDIR ${HOME}/workspace

COPY --chmod=755 rootfs/usr/local/bin/ /usr/local/bin/
COPY --chmod=755 rootfs/usr/local/lib/agent-base/ /usr/local/lib/agent-base/
COPY --chmod=755 rootfs/etc/services.d/ /etc/services.d/
COPY --chmod=755 rootfs/etc/cont-init.d/ /etc/cont-init.d/
COPY --chmod=755 rootfs/etc/agent-entrypoint.d/ /etc/agent-entrypoint.d/
# The hook directory README is documentation, not an executable hook.
RUN chmod 644 /etc/agent-entrypoint.d/README

# Checks the agent service (see agent-healthcheck); the daemon is reported as
# a warning, not a failure, because it cannot start on hosts whose own Docker
# is rootless — the agent still works there.
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --start-interval=5s --retries=3 \
    CMD ["/usr/local/bin/agent-healthcheck"]

# agent-entrypoint only stashes the container's CMD for the agent service and
# execs /init: s6 does not forward docker CMD args to services. CMD defaults
# to empty, so a bare `docker run` starts the agent with no arguments.
ENTRYPOINT ["/usr/local/bin/agent-entrypoint"]
CMD []


# =============================================================================
# test — build-time checks that need no daemon: the user exists with the
# requested uid/gid, the tool matrix resolves and runs, and every script passes
# shellcheck. Built by the "test" bake target and by `make test`; never pushed.
# The runtime checks (services coming up, storage driver) need the container's
# devices and seccomp profile, so they live in scripts/smoke.sh instead.
#
# The s6 service scripts start with #!/command/with-contenv, which shellcheck
# cannot detect: -s bash names the interpreter and SC1008 silences the shebang
# complaint. The shebang must stay on line 1 for the kernel, so this is linted
# as a separate invocation rather than by rewriting the scripts.
# =============================================================================
FROM agent-base AS test

ARG AGENT_USER=agent
ARG AGENT_UID=1000
ARG AGENT_GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends shellcheck \
    && rm -rf /var/lib/apt/lists/* \
    && shellcheck /usr/local/bin/agent-entrypoint /usr/local/bin/agent-healthcheck \
        /usr/local/bin/agent-run \
        /usr/local/lib/agent-base/selftest.sh \
    && shellcheck -s bash -e SC1008 -- \
        /etc/cont-init.d/10-prepare \
        /etc/services.d/dockerd/run /etc/services.d/dockerd/finish \
        /etc/services.d/agent/run /etc/services.d/agent/finish

# Run the tool matrix as the agent user, exactly like the runtime does.
RUN /command/s6-setuidgid "${AGENT_USER}" /usr/local/lib/agent-base/selftest.sh --no-docker
