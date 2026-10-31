# Configuration

## Environment

Everything is optional; the defaults work with no configuration.

| Variable | Default | Meaning |
|---|---|---|
| `DSH_PORT` | `3080` | port dsh listens on (passed as `--port`) |
| `DSH_HOST` | – | `--host`; wildcard addresses are refused, see below |
| `DSH_TRUSTED_HOSTS` | – | space-separated `--trusted-host` values for `/api` |
| `DSH_DOCKERD` | `1` | `0` skips the inner Docker daemon |
| `DSH_HOME` | `/home/agent/.dsh` | profiles, credentials, sessions |
| `DSH_WORKSPACE` | `/home/agent/workspace` | working directory dsh starts in |
| `AGENT_BASE` | `agent-base:1.5.0` | base image the Dockerfile builds from |
| `DSH_VERSION` | `0.2.1-rc.5` | exact `@deepseek-ai/dsh` version from npm |
| `NODE_VERSION` | `22.23.4` | Node release compiled from source |
| `DSH_IMAGE` | `dsh:local` | tag for the built image |
| `DSH_HOME_HOST` | `dsh-home` | volume or host path mounted at `DSH_HOME` |

The sandbox has its own switches (`AGENT_DOCKERD`, `AGENT_HEALTHCHECK`,
`AGENT_CPUS`, `AGENT_SKILLS_HOST`, proxy variables…), documented in
[agent-base's configuration reference](../../../docs/configuration.md).

## Host networking

dsh's web server binds `127.0.0.1` and refuses every wildcard address, because it
exposes remote code execution to anyone who can reach it. A container has its own
loopback, so `ports:` cannot reach it: the published port forwards to the
container's routable address, where nothing listens.

The compose file therefore sets `network_mode: host`. The container's
`127.0.0.1:3080` is the host's `127.0.0.1:3080`, so the UI answers at
<http://localhost:3080> with the same loopback-only exposure dsh intends. Nothing
is published to the LAN.

Consequences:

- host networking is Linux-only; on Docker Desktop for macOS/Windows run dsh on
  the host instead of in a container;
- the container shares the host's network namespace, so it has no network
  isolation from the host;
- `DSH_HOST` stays unset. Setting it to a wildcard is refused by both dsh and the
  flag hook; use `DSH_HOST=127.0.0.1` only if you need to be explicit.

## Credentials

The DeepSeek API key is entered in the UI (Settings → Models) and stored in
`$DSH_HOME/.credentials.yaml` under `refs.DEEPSEEK_API_KEY`. That file is mode
0600 and owned by the agent user; it lives in the `dsh-home` volume and survives
recreation.

`DEEPSEEK_API_KEY` is deliberately **not** read from the environment: the
inherited environment outranks the credentials file, so setting it would hide
whether the file path works.

## State

| Path | Volume | Holds |
|---|---|---|
| `/home/agent/.dsh` | `dsh-home` | profiles, credentials, sessions |
| `/home/agent/workspace` | – | working directory (`DSH_WORKSPACE`); not persisted unless a local override binds it |
| `/home/agent/.local/share/docker` | `agent-docker` | inner daemon data |

## Healthcheck

The image's healthcheck (`/usr/local/lib/dsh-healthcheck.mjs`) loads the
browser-session secret from the credentials file, signs a 60-second cookie the
way dsh does, and requires HTTP 200 on `/`. A pass proves the server is up, the
credentials store loads and browser auth accepts a valid session.

Override it with `AGENT_HEALTHCHECK=off` or a `HEALTHCHECK` in a child image if
that is not the signal you want.
