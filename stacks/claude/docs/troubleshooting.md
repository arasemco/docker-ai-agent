# Troubleshooting

## `claude` says it needs a terminal

The CLI is a TUI and refuses to start without a TTY. Start it from an exec
session, not from the service's stdio:

```bash
make exec PROFILE=claude
claude
```

## Not signed in

`make smoke PROFILE=claude` prints `claude auth status`:

- `Not logged in` (authMethod `none`) — neither `ANTHROPIC_API_KEY` nor
  `CLAUDE_CODE_OAUTH_TOKEN` reached the container; check `.env` and
  `docker compose config`.
- A key is set but the CLI still asks — interactive sessions ask once whether to
  use `ANTHROPIC_API_KEY`, and remember the answer. Approve it; `claude -p` does
  not ask.
- Subscription login: `/login` opens a browser callback that cannot reach the
  host from inside the container. Run `claude setup-token` on the host and set
  `CLAUDE_CODE_OAUTH_TOKEN` instead.

## Remote Control is unavailable

`claude remote-control` needs a subscription login. It exits with an error when:

- the account uses an API key instead of a Pro/Max/Ultra/Team/Enterprise plan;
- `ANTHROPIC_BASE_URL` points anywhere but `api.anthropic.com`;
- the workspace is not trusted (run it once from an interactive session and
  accept the prompt);
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` or `DISABLE_GROWTHBOOK` is set.

## Settings or credentials are not persisted

Check the volume in `.env`:

```bash
CLAUDE_HOME_HOST=claude-home     # named volume, or a host path
```

A host path must be writable by uid 1000. If it is not, Claude Code cannot write
`$CLAUDE_CONFIG_DIR`, and the first-run login disappears with the container.

## Files in the workspace are not writable

The CLI runs as uid 1000 when you follow `make exec`. A bind mount whose host
directory belongs to another user is read-only for it. Chown the directory to
uid/gid 1000 on the host, or use a named volume.

## The inner Docker daemon is missing

`make smoke` prints the daemon version or `SKIP`. The daemon is optional for
Claude Code, but tools it runs may want it. On a host whose own Docker is
rootless, `SKIP` is expected; `SMOKE_REQUIRE_DOCKER=1 make smoke PROFILE=claude`
turns that into a failure.
