# syntax=docker/dockerfile:1
# =============================================================================
# dsh — the DeepSeek Harness Web UI on top of agent-base (Node 22 variant)
# =============================================================================
# agent-base-node22 supplies Node 22; this image adds dsh, pnpm (for
# `dsh plugin`), the DSH_* flag hook, the launch line, the authenticated
# healthcheck and the state manifest.
# =============================================================================
ARG AGENT_BASE
FROM ${AGENT_BASE} AS runtime
ARG AGENT_CONTRACT=2
ARG DSH_VERSION
ARG PNPM_VERSION

RUN npm install --global --no-fund --no-audit --no-update-notifier "pnpm@${PNPM_VERSION}" \
    && pnpm --version

RUN npm install --global --no-fund --no-audit --no-update-notifier "@deepseek-ai/dsh@${DSH_VERSION}" \
    && dsh --version \
    && install -d -o 1000 -g 1000 -m 700 "/home/agent/.dsh" \
    && chown -R 1000:1000 "/home/agent/.dsh"

COPY --chmod=644 healthcheck.mjs /usr/local/lib/dsh-healthcheck.mjs
COPY --chmod=755 agent-launch.d/agent.sh /etc/agent-launch.d/agent.sh
COPY --chmod=644 state.d/ /etc/agent-state.d/
COPY --chmod=755 health.d/ /etc/agent-healthcheck.d/
COPY --chmod=755 hooks/20-dsh-flags.sh /etc/agent-entrypoint.d/20-dsh-flags.sh

ENV DSH_HOME=/home/agent/.dsh \
    DSH_WORKSPACE=/home/agent/workspace \
    DSH_PORT=3080 \
    DSH_PACKAGE=/usr/local/lib/node_modules/@deepseek-ai/dsh/package.json \
    AGENT_WORKSPACE=/home/agent/workspace

EXPOSE 3080

FROM runtime AS test
ARG AGENT_CONTRACT
RUN /usr/local/lib/agent-base/contract.sh \
    && [ "$(cat /etc/agent-base/CONTRACT)" = "${AGENT_CONTRACT}" ] \
    && dsh --version

FROM runtime AS integration
ENV DSH_HOME=/tmp/dsh-test/home
RUN install -d -m 700 /tmp/dsh-test/home /tmp/dsh-test/workspace
WORKDIR /tmp/dsh-test/workspace
RUN --mount=type=secret,id=dsh_credentials,target=/tmp/dsh-test/home/.credentials.yaml,uid=1000,gid=1000,mode=0600,required=true <<'SCRIPT'
set -eu
creds="${DSH_HOME}/.credentials.yaml"
key="$(awk '
  /^refs:/ { in_refs = 1; next }
  in_refs && /^[^ \t#]/ { in_refs = 0 }
  in_refs && $1 == "DEEPSEEK_API_KEY:" {
    v = $2; gsub(/^["\047]|["\047]$/, "", v); print v; exit
  }' "${creds}")"
if [ -z "${key}" ]; then
    echo "test: no refs.DEEPSEEK_API_KEY in the dsh_credentials secret" >&2
    exit 1
fi
status="$(printf 'Authorization: Bearer %s\n' "${key}" \
    | curl -sS -o /dev/null -w '%{http_code}' -H @- https://api.deepseek.com/models)"
unset key
if [ "${status}" != 200 ]; then
    echo "test: DeepSeek API rejected the key (GET /models -> HTTP ${status})" >&2
    exit 1
fi
timeout 300 dsh --profile headless "Reply with exactly the word OK and nothing else." > /tmp/dsh-test/answer
grep -qi ok /tmp/dsh-test/answer
SCRIPT
