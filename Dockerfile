ARG DOCKER_VERSION=29.8.1
FROM docker:${DOCKER_VERSION}-dind-rootless

ARG OPENCODE_USER=opencode
ARG OPENCODE_UID=1000
ARG OPENCODE_GID=1000
ARG OPENCODE_VERSION=1.19.5

USER root

# Ensure libgcc and libstdc++ are present for musl binaries
RUN apk add --no-cache shadow libgcc libstdc++ \
    && existing_group="$(getent group "${OPENCODE_GID}" | cut -d: -f1)" \
    && if [ -n "${existing_group}" ] && [ "${existing_group}" != "${OPENCODE_USER}" ]; then \
        groupmod --new-name "${OPENCODE_USER}" "${existing_group}"; \
    elif [ -z "${existing_group}" ]; then \
        groupadd --gid "${OPENCODE_GID}" "${OPENCODE_USER}"; \
    fi \
    && existing_user="$(getent passwd "${OPENCODE_UID}" | cut -d: -f1)" \
    && if [ -n "${existing_user}" ] && [ "${existing_user}" != "${OPENCODE_USER}" ]; then \
        usermod --login "${OPENCODE_USER}" --gid "${OPENCODE_GID}" --home "/home/${OPENCODE_USER}" --move-home --shell /bin/bash "${existing_user}"; \
    elif [ -z "${existing_user}" ]; then \
        useradd --uid "${OPENCODE_UID}" --gid "${OPENCODE_GID}" --create-home --shell /bin/bash "${OPENCODE_USER}"; \
    fi

RUN grep -q "^${OPENCODE_USER}:" /etc/subuid || echo "${OPENCODE_USER}:100000:65536" >> /etc/subuid \
    && grep -q "^${OPENCODE_USER}:" /etc/subgid || echo "${OPENCODE_USER}:100000:65536" >> /etc/subgid

# Pre-create OpenCode's XDG directories with the right owner so named volumes
# mounted here inherit user ownership instead of being created root-owned.
RUN mkdir -p "/home/${OPENCODE_USER}/.local/share/opencode" \
        "/home/${OPENCODE_USER}/.local/state/opencode" \
        "/home/${OPENCODE_USER}/.cache/opencode" \
        "/home/${OPENCODE_USER}/.config/opencode" \
        "/home/${OPENCODE_USER}/workspace" \
    && chown -R "${OPENCODE_USER}:${OPENCODE_USER}" "/home/${OPENCODE_USER}"

# Default provider config (Ollama), seeded into the config volume on first use.
COPY --chown=${OPENCODE_UID}:${OPENCODE_GID} opencode.jsonc /home/${OPENCODE_USER}/.config/opencode/opencode.jsonc

# Common utilities and build packages
RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        wget \
        jq \
        yq \
        python3 \
        py3-pip \
        rsync \
        git \
        github-cli \
        gnupg \
        openssh-client \
        procps \
        nano \
        nodejs \
        npm \
        shellcheck \
        build-base \
        linux-headers \
        python3-dev \
        cmake \
        meson \
        samurai \
        pkgconf \
        patch \
        libffi-dev \
        openssl-dev \
        zlib-dev \
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
        fd \
        tmux \
        htop \
        strace \
        lsof \
        bind-tools \
        zip \
        unzip \
        xz \
        zstd \
        sqlite \
        gettext-envsubst \
        socat

ENV UV_INSTALL_DIR=/usr/local/bin
RUN curl -fsSL https://astral.sh/uv/install.sh | sh

USER ${OPENCODE_USER}
ENV HOME=/home/${OPENCODE_USER} \
    UV_LINK_MODE=copy
WORKDIR ${HOME}/workspace

# Install OpenCode official binary (pin with --build-arg OPENCODE_VERSION=x.y.z)
ENV PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"
RUN if [ -n "${OPENCODE_VERSION}" ]; then \
        curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}"; \
    else \
        curl -fsSL https://opencode.ai/install | bash; \
    fi \
    && echo 'export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc" \
    && echo 'export UV_LINK_MODE="copy"' >> "${HOME}/.bashrc"

ENV XDG_RUNTIME_DIR="${HOME}/.docker/run"
ENV DOCKER_HOST="unix://${HOME}/.docker/run/docker.sock"

# Expose OpenCode's default Web UI port
EXPOSE 4096

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD opencode --version || exit 1

COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default to starting the Web UI
CMD ["web", "--port", "4096", "--hostname", "0.0.0.0"]
