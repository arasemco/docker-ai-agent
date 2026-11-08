# Environment

Generated from `config/knobs.env`; do not edit.

| Variable | Default | Meaning |
|---|---|---|
| `AGENT_DOCKERD` | `1` | start the inner rootless Docker daemon |
| `AGENT_DOCKERD_TIMEOUT` | `30` | seconds to wait for dockerd readiness |
| `AGENT_DOCKERD_MAX_RESTARTS` | `3` | failed dockerd starts before idling |
| `AGENT_RESTART_MAX` | `3` | failed agent starts before stopping the container |
| `AGENT_DOCKER_VOLUME` | `agent-docker` | volume or host path for daemon data |
| `AGENT_UV_CACHE_VOLUME` | `uv-cache` | named volume for the uv cache |
| `AGENT_UV_DATA_VOLUME` | `uv-data` | named volume for uv data |
| `AGENT_GNUPG_VOLUME` | `agent-gnupg` | named volume for the GPG home (keyring, gpg-agent, SSH socket) |
| `AGENT_SSH_VOLUME` | `agent-ssh` | named volume for the SSH config and keys |
| `AGENT_WORKSPACE_HOST` | `agent-workspace` | volume or host path for the sandbox workspace |
| `AGENT_HOSTNAME` | `agent` | container hostname where compose allows it |
| `AGENT_CPUS` | `2` | CPU limit for the common service |
| `AGENT_MEMORY` | `4G` | memory limit for the common service |
| `AGENT_HEALTHCHECK` | `auto` | auto | stack | docker | agent | url:<url> | off |
| `AGENT_HEALTH_URL` | `-` | extra URL the healthcheck must reach |
| `AGENT_SUBID_REMAP` | `1` | rewrite subuid/subgid ranges for a rootless host |
| `PROXY` | `-` | one proxy for every scheme |
| `HTTP_PROXY` | `-` | scheme-specific proxy |
| `HTTPS_PROXY` | `-` | scheme-specific proxy |
| `ALL_PROXY` | `-` | scheme-specific proxy |
| `NO_PROXY` | `-` | hosts that bypass the proxy |
| `http_proxy` | `-` | - |
| `https_proxy` | `-` | - |
| `all_proxy` | `-` | - |
| `no_proxy` | `-` | - |
| `OPENCODE_PORT` | `4096` | Web UI port |
| `OPENCODE_BIND_IP` | `127.0.0.1` | published interface |
| `OPENCODE_SERVER_PASSWORD` | `changeme123` | HTTP basic auth password |
| `OPENCODE_CONFIG_HOST` | `opencode-config` | volume or host path for config |
| `OPENCODE_DATA_HOST` | `opencode-data` | volume or host path for data |
| `OPENCODE_STATE_HOST` | `opencode-state` | volume or host path for state |
| `OPENCODE_WORKSPACE_HOST` | `opencode-workspace` | volume or host path for the workspace |
| `ANTHROPIC_API_KEY` | `-` | provider credential |
| `OPENAI_API_KEY` | `-` | provider credential |
| `GEMINI_API_KEY` | `-` | provider credential |
| `OLLAMA_BASE_URL` | `-` | local OpenAI-compatible endpoint |
| `OLLAMA_API_KEY` | `-` | key for that endpoint |
| `DSH_PORT` | `3080` | Web UI port |
| `DSH_TRUSTED_HOSTS` | `-` | space-separated trusted hosts for /api |
| `DSH_HOME_HOST` | `dsh-home` | volume or host path for profiles/credentials |
| `DSH_WORKSPACE_HOST` | `dsh-workspace` | volume or host path for the workspace |
| `CLAUDE_HOME_HOST` | `claude-home` | volume or host path for Claude state |
| `CLAUDE_WORKSPACE_HOST` | `claude-workspace` | volume or host path for the workspace |
| `CLAUDE_CODE_OAUTH_TOKEN` | `-` | long-lived subscription token from `claude setup-token` |
