---
name: debug-healthcheck
description: Diagnose the dsh healthcheck and the UI behind it — 401 vs failure, missing browser-session secret, port mismatch, crashed server, or a healthcheck that passes while the browser cannot use the UI. Use when the container is unhealthy or the UI does not answer.
metadata:
  area: runtime
  files: stacks/dsh/image/healthcheck.mjs, tooling/smoke.sh
---

# Debug the healthcheck and the UI

## What the healthcheck proves

`/usr/local/lib/dsh-healthcheck.mjs` reads the browser-session secret from
`$DSH_HOME/.credentials.yaml`, signs a 60-second cookie exactly as dsh does, and
requires HTTP 200 on `/`. It therefore fails for three distinct reasons, which
the message distinguishes:

| Message | Meaning | Fix |
|---|---|---|
| `cannot read …/.credentials.yaml` | the file or the volume is missing | `make up` once; the file is written on first use |
| `no client-connection/browser-session secret … yet` | the UI has never been signed in | open the launch URL from `make logs` and sign in |
| `GET / with a signed session cookie -> HTTP 401` | the server rejects the cookie | check `DSH_HOME` and `DSH_PORT` are the ones the server used |
| `GET / failed: …` | nothing listens on that port | see the port and server checks below |

## Order of checks

```bash
make ps
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3080/   # 401 = server up
make logs                                                          # hook + agent lines
docker compose --profile dsh exec --no-TTY dsh node /usr/local/lib/dsh-healthcheck.mjs
```

## Port and host

The healthcheck targets `127.0.0.1:$DSH_PORT` with a `Host` header built from the
same value. If the server was started with a different `--port`, the healthcheck
probes the wrong place: export the same `DSH_PORT` for both.

Host networking is required: dsh binds loopback only, so on a bridge network the
server listens on the container's own 127.0.0.1 where nothing can reach it.

## Server up, browser unhappy

- The launch URL carries a one-time token; an old one is rejected. Take a fresh
  one from `make logs`.
- `DSH_TRUSTED_HOSTS` matters only for `/api` browser trust, not for the initial
  page.
- Behind a reverse proxy, the `Host` the browser sends must be a trusted
  authority, or authentication is refused.

## Verify a fix

```bash
docker compose --profile dsh exec --no-TTY dsh node /usr/local/lib/dsh-healthcheck.mjs && echo healthy
make smoke
```
