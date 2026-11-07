# Troubleshooting

## The UI does not answer

1. `make ps` — is the container running?
2. `make logs` — the `[hook]`, `[agent]` and s6 lines show what ran.
3. Is it listening? `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3080/`
   should print `401` once the container is up. `000` means nothing listens.
4. Host networking: the UI is only reachable on the host running Docker. On
   macOS/Windows it will never work; run dsh on the host there.

## The healthcheck fails

`make smoke` runs it and prints the reason. Common causes:

- **No credentials yet.** dsh has not been signed in, so `.credentials.yaml` has
  no `client-connection/browser-session` record. Open the UI once and sign in
  with the launch URL; the record is written on first use.
- **Port mismatch.** The healthcheck targets `127.0.0.1:$DSH_PORT`; if the server
  was started on another port, export the same `DSH_PORT`.
- **Server crashed after start.** `make logs` shows the exit; the CLI status is in
  `/run/agent/exit-code`.

## HTTP 401 in a browser

Expected without a session: dsh answers 401 until a browser signs in through the
launch token it prints at start-up. Copy the URL from `make logs`.

## `DSH_HOST=0.0.0.0` is refused

By design. dsh's flag parser and the image's hook both refuse wildcard addresses;
the UI is loopback-only. Use host networking instead (the default) and keep
`DSH_HOST` unset.

## The inner Docker daemon is not running

`make smoke` prints the daemon version or `SKIP`. The daemon log is
`/home/agent/.docker/dockerd.log` inside the container. Check that the stack was
started with the sandbox settings (`make up` provides them) and that the base
image is agent-base 1.4.1 or newer — older versions cannot start the daemon when
the container itself runs under a rootless host daemon.

## The build takes very long

Expected on a cold build: the Node 22 base variant is built once; later stack
builds reuse the cached base layers.

## Exit status looks wrong

The container's exit status is s6's, not the CLI's. dsh's own status is in
`/run/agent/exit-code` and in the log.
