---
name: debug-web-ui
description: Diagnose a Web UI that does not answer, answers 401 unexpectedly, reports unhealthy, or serves a stale configuration. Use when the stack is running but the browser cannot use it.
metadata:
  area: runtime
  files: docker-compose.yml, scripts/smoke.sh
---

# Debug the Web UI

## Order of checks

```bash
make ps                        # is the container running, and since when?
make smoke                     # HTTP status, s6 services, daemon, version
make logs                      # s6 and [agent] lines
```

## Symptoms

**No answer at all (`000`).** The published port is free but nothing listens.
Check the port in `.env` matches what the process was told (`OPENCODE_PORT`
reaches the image's `services.d/agent/run`, which starts `opencode web --port …`)
and that no other stack publishes it.
`make logs` shows the CLI's own startup output.

**The UI answers from the host but not from another machine.** Expected with the
default `OPENCODE_BIND_IP=127.0.0.1`. Set `OPENCODE_BIND_IP=0.0.0.0` and a real
`OPENCODE_SERVER_PASSWORD`.

**HTTP 401.** Working as intended: basic auth. Use the password from `.env`.

**Unhealthy.** The healthcheck proves the s6 `agent` service is up; unhealthy
means the CLI exited and s6 stopped restarting it. `make logs` and
`/run/agent/exit-code` inside the container say why.
A dead inner daemon only produces a warning, not a failure.

**Container exits immediately.** The agent service ran the image's launch line
and it returned. Check the `[agent]` log line for the exact command; on an agent
stack the long-running subcommand belongs in `image/services.d/agent/run`.

**Stale configuration.** The container reads `opencode.jsonc` from the config
volume; if `OPENCODE_CONFIG_HOST` binds a host directory, changes must be made
there. Restart after editing: `make down && make up`.

## Verify a fix

```bash
docker compose --profile opencode exec --no-TTY opencode opencode --version
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4096/
make smoke
```
