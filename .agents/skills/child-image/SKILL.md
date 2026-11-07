---
name: child-image
description: Build an external agent image on top of agent-base — install the CLI, ship the launch file, state manifest and optional health fragment, and keep the base contract. Use for consumers outside this repository; in-repo stacks use stack.yaml and bake.hcl.
metadata:
  area: consumer
  files: examples/child-image/
---

# Build a child image

The base provides the sandbox and the contract; the child provides one CLI and
the contract files.

```dockerfile
ARG AGENT_BASE=agent-base:2.0.0
FROM ${AGENT_BASE}
ARG AGENT_CONTRACT=2
ARG CLI_VERSION=1.0.0

RUN npm install --global --no-fund --no-audit --no-update-notifier "my-cli@${CLI_VERSION}" \
    && my-cli --version

COPY agent-launch.d/agent.sh /etc/agent-launch.d/agent.sh
COPY state.d/ /etc/agent-state.d/
# optional:
# COPY hooks/ /etc/agent-entrypoint.d/
# COPY health.d/ /etc/agent-healthcheck.d/
```

`agent-launch.d/agent.sh` sets the launch line; it does not replace the base
run script:

```bash
# shellcheck disable=SC2034
AGENT_LAUNCH=(my-cli web --port 8080)
```

`state.d/<id>.paths` uses `$AGENT_HOME` and an optional mode:

```
$AGENT_HOME/.config/my-cli:0700
```

Rules:

- pin `AGENT_BASE` to a tag; pin the CLI exactly;
- do not end with `USER 1000:1000`; `/init` must stay PID 1 as root;
- do not ship a `services.d/agent/run`; the base one is fixed;
- hooks may rewrite `$@` and may abort startup by design;
- a stack test stage should run `/usr/local/lib/agent-base/contract.sh` and
  assert `AGENT_CONTRACT` matches `/etc/agent-base/CONTRACT`.

See [examples/child-image](../../../examples/child-image).
