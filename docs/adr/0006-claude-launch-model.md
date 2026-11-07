# 0006 — Claude Code launch model

Status: accepted

Claude Code is an interactive TUI. The image keeps the base idler as its agent
service and the CLI runs from an exec session (`make exec PROFILE=claude`). The
TTY `command:` form is a host-overlay choice, never a tracked launch line, and
first-run onboarding is handled interactively.
