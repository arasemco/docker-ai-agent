---
name: child-image
description: Build a new agent image on top of agent-base — install the CLI, own its state directories, set AGENT_CMD, and wire a compose stack onto the shared anchors. Use when adding support for another agent CLI or restructuring an existing child stack.
metadata:
  area: consumer
  files: examples/child-image/
---

# Build a child image

agent-base provides the environment; a child provides exactly one CLI and the
metadata around it.

## Dockerfile

```dockerfile
ARG AGENT_BASE=agent-base:1.4.0
FROM ${AGENT_BASE}

ARG CLI_VERSION=1.0.0
RUN npm install --global --no-fund --no-audit --no-update-notifier "my-cli@${CLI_VERSION}" \
    && my-cli --version

# State directories must exist owned by the agent user: a fresh named volume
# mounted on a path the image does not own comes up root-owned.
RUN install -d -o 1000 -g 1000 "/home/agent/.config/my-cli" \
    && chown -R 1000:1000 "/home/agent/.config"

COPY hooks/ /etc/agent-entrypoint.d/     # optional
ENV AGENT_CMD=my-cli
```

Rules:

- pin `AGENT_BASE` to a tag (never `:latest`) and bump it deliberately;
- pin the CLI version exactly;
- create every directory the CLI writes to, owned by uid 1000 — including the
  parents `COPY --chown` would create as root;
- run the CLI's `--version` in the build so a broken install fails the build;
- **do not end with `USER 1000:1000`**: `/init` must be PID 1 as root, and the
  services drop to the agent user themselves;
- no provider config baked in unless it is genuinely generic; ship it as an
  example instead.

## Compose

```yaml
services:
  my-cli:
    image: my-cli:local
    pull_policy: build
    build:
      context: ./image
      args:
        AGENT_BASE: agent-base:1.4.0
        CLI_VERSION: 1.0.0
    hostname: my-cli
    command: ["--help"]                  # arguments for AGENT_CMD
    volumes:
      - ${MY_CLI_HOME_HOST:-my-cli-home}:/home/agent/.config/my-cli
volumes:
  agent-docker:                          # the daemon anchor mounts it
  my-cli-home:
```

Stand alone by copying the shared anchors (`x-sandbox`, `x-agent-env`,
`x-docker`, `x-skills`) from this repository's `docker-compose.yml`, or add the
stack here under `stacks/<name>/` with a service that merges them and its own
`profiles:` entry.

## Runtime expectations inherited from agent-base

- `docker exec` lands as root (PID 1's user); use `--user 1000`.
- The container's exit status is s6's; the CLI's is in `/run/agent/exit-code`.
- The default healthcheck checks that `AGENT_CMD` is alive. Override
  `HEALTHCHECK` when the CLI has a real readiness signal.
- Hooks in `/etc/agent-entrypoint.d/` can rewrite arguments before the CLI
  starts; they run as the agent user.

## Verify

```bash
docker compose up -d --build    # then probe the CLI/UI
docker compose exec --user 1000 my-cli my-cli --version
```

## References

- [examples/child-image](../../../examples/child-image)
- [docs/architecture.md](../../../docs/architecture.md)
- [docs/configuration.md](../../../docs/configuration.md)
