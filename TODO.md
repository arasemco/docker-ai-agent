# TODO

## Claude Code launch model

The claude stack keeps the base idler as the agent service and starts `claude`
from `make exec`. Two alternatives were tried in a local overlay:

- **`command:` as s6's top process** (`/command/s6-setuidgid agent claude …`):
  gets the container TTY, but Claude is unsupervised, its exit stops the
  container, and the healthcheck only proves the idle service.
- **A `configs:`-injected `services.d/agent/run`**: keeps s6 supervision, but
  the service has no TTY, so it needs `script(1)` or tmux — and an unattachable
  pty cannot answer the first-run onboarding/trust prompts.

Decide whether either belongs in the image's launch line, and how to handle
first-run onboarding, Remote Control login, and readiness before relying on it.
