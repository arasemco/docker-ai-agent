---
name: child-image
description: Build a new agent image on top of agent-base — install the CLI, own its state directories, ship its s6 launch line, and wire a compose stack onto the shared common service. Use when adding support for another agent CLI or restructuring an existing child stack.
metadata:
  area: consumer
  files: examples/child-image/
---

# Build a child image

agent-base provides the environment; a child provides exactly one CLI and the
metadata around it.

## Dockerfile

```dockerfile
ARG AGENT_BASE=agent-base:1.5.0
FROM ${AGENT_BASE}

ARG CLI_VERSION=1.0.0
RUN npm install --global --no-fund --no-audit --no-update-notifier "my-cli@${CLI_VERSION}" \
    && my-cli --version

# State directories must exist owned by the agent user: a fresh named volume
# mounted on a path the image does not own comes up root-owned.
RUN install -d -o 1000 -g 1000 "/home/agent/.config/my-cli" \
    && chown -R 1000:1000 "/home/agent/.config"

COPY hooks/ /etc/agent-entrypoint.d/     # optional

# What the s6 agent service runs: executable plus arguments. This replaces the
# base image's run script, so the image owns its launch line.
COPY services.d/agent/run /etc/services.d/agent/run
```

with `services.d/agent/run` reduced to one call:

```bash
#!/command/with-contenv bash
set -euo pipefail
exec /usr/local/bin/agent-service-start my-cli web --port 8080
```

The first argument is the executable; the rest are its arguments. `agent-run`
splits the executable off before sourcing hooks, so hooks only rewrite flags.

`agent-service-start` waits for the Docker daemon, drops to the agent user and
hands the arguments to `agent-run`. Run scripts start with
`#!/command/with-contenv bash` so they inherit the container environment.

Rules:

- pin `AGENT_BASE` to a tag (never `:latest`) and bump it deliberately;
- pin the CLI version exactly;
- create every directory the CLI writes to, owned by uid 1000 — including the
  parents `COPY --chown` would create as root;
- run the CLI's `--version` in the build so a broken install fails the build;
- **do not end with `USER 1000:1000`**: `/init` must be PID 1 as root, and the
  services drop to the agent user themselves;
- name the executable and its arguments in `services.d/agent/run`, not in the
  compose file: a service carries env, ports and volumes only; a container
  `CMD` is a separate foreground command run by s6, not the service's launch
  line;
- no provider config baked in unless it is genuinely generic; ship it as an
  example instead.

## Compose

```yaml
services:
  my-cli:
    profiles: ["my-cli"]
    extends: {file: ./compose.common.yml, service: common}
    image: my-cli:local
    build:
      context: ./image
      args:
        AGENT_BASE: agent-base:1.5.0
        CLI_VERSION: 1.0.0
    hostname: my-cli
    # No command: the image's s6 agent service defines the launch line.
    volumes:
      - ${MY_CLI_HOME_HOST:-my-cli-home}:/home/agent/.config/my-cli
volumes:
  agent-docker:                          # declared by the extending project
  my-cli-home:
```

Stand alone by copying `compose.common.yml` (the `common` service: sandbox,
environment and daemon volume) into the composing project, or add the stack
here under `stacks/<name>/` with a service that extends it and its own
`profiles:` entry.

## Runtime expectations inherited from agent-base

- `docker exec` lands as root (PID 1's user); use `--user 1000`.
- The container's exit status is s6's; the CLI's is in `/run/agent/exit-code`.
- The default healthcheck checks that the s6 `agent` service is up. Override
  `HEALTHCHECK` when the CLI has a real readiness signal.
- Hooks in `/etc/agent-entrypoint.d/` can rewrite the CLI's arguments before it
  starts; they run as the agent user, with the executable already split off.

## Verify

```bash
docker compose up -d --build    # then probe the CLI/UI
docker compose exec --user 1000 my-cli my-cli --version
```

## References

- [examples/child-image](../../../examples/child-image)
- [docs/architecture.md](../../../docs/architecture.md)
- [docs/configuration.md](../../../docs/configuration.md)
