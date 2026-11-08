# agent-base contract (version 2)

The base image publishes a versioned interface to the stack modules built on
top of it. A breaking change bumps `base/CONTRACT`; every stack declares
`ARG AGENT_CONTRACT` and its test stage asserts it matches.

## Image invariants

- `/init` (s6-overlay) is PID 1 as root; no image ends with `USER`.
- `dockerd`, `gpg-agent` and `agent` are the longruns; all drop to `agent`
  (uid/gid 1000).
- The identity is frozen: `agent:1000`, home `/home/agent`. Host binds and
  named volumes rely on it; it is not a deployment knob.
- The base owns `HEALTHCHECK`; stacks add fragments, never replace the check.

## Extension points

| What | Stack ships | Semantics |
|---|---|---|
| launch line | `/etc/agent-launch.d/agent.sh` | sourced as the agent user; sets `AGENT_LAUNCH=(exe args…)`; non-empty; `agent-run` then sources hooks and execs it |
| hooks | `/etc/agent-entrypoint.d/NN-*.sh` | sourced under `set -e`, may rewrite `$@`, may abort startup by design |
| health | `/etc/agent-healthcheck.d/NN-*.sh` | executable; exit 0 healthy, non-zero unhealthy; run in `auto`/`stack` mode |
| state | `/etc/agent-state.d/<id>.paths` | `path[:mode]` lines; `$AGENT_HOME` expands to the account home; base creates and chowns them |
| contract | `ARG AGENT_CONTRACT` | integer matching `base/CONTRACT`; asserted by the stack test stage |

## Required Dockerfile shape

```dockerfile
ARG AGENT_BASE
FROM ${AGENT_BASE}
ARG AGENT_CONTRACT=2
ARG <CLI>_VERSION
# install the CLI, create nothing owned by a literal uid
COPY agent-launch.d/agent.sh /etc/agent-launch.d/agent.sh
COPY state.d/ /etc/agent-state.d/
COPY health.d/ /etc/agent-healthcheck.d/     # optional
COPY hooks/ /etc/agent-entrypoint.d/         # optional
```
