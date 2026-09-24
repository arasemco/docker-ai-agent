// =============================================================================
// healthcheck.mjs — HEALTHCHECK for the dsh Web UI (see dsh/Dockerfile).
//
// `GET /` answers 401 until the browser has signed in through the
// `?token=` URL dsh prints, so a plain `curl -f /` can never pass. That
// launch token only exists in the running process's memory, but the cookie
// it mints is just an HMAC over a small JSON payload, signed with a
// persistent secret dsh stores in $DSH_HOME/.credentials.yaml under the
// `client-connection/browser-session` record (upstream
// packages/client/connection/src/browser-auth.ts). This script loads that
// secret, signs a 60-second cookie for 127.0.0.1:$DSH_PORT exactly the way
// dsh does, and requires a 200 for `/`. A pass therefore proves the server is
// up, its credentials store loads, and its browser auth accepts a valid session.
//
// Runs as the container's user, dsh (see the Dockerfile's USER), which owns
// the 0600 credentials file. Parses YAML with the same
// `yaml` package dsh's own credentials-local plugin resolves, rather than a
// hand-rolled parser.
// =============================================================================
import { createHash, createHmac } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { request } from 'node:http'
import { createRequire } from 'node:module'
import { join } from 'node:path'

const { parse } = createRequire(
  '/usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-credentials-local/package.json',
)('yaml')

const fail = (message) => {
  console.error(`healthcheck: ${message}`)
  process.exit(1)
}

const b64url = (buffer) => Buffer.from(buffer).toString('base64url')

const home = process.env.DSH_HOME || '/home/dsh/.dsh'
const port = process.env.DSH_PORT || '3080'

let secret
try {
  const document = parse(readFileSync(join(home, '.credentials.yaml'), 'utf8'))
  secret = document?.records?.['client-connection/browser-session']?.payload?.secret
} catch (error) {
  fail(`cannot read ${home}/.credentials.yaml: ${error.message}`)
}
if (typeof secret !== 'string') fail('no client-connection/browser-session secret in .credentials.yaml yet')

// Same normalization dsh applies to the Host header (new URL(...).host).
const authority = new URL(`http://127.0.0.1:${port}`).host
const issuedAt = Date.now()
const body = b64url(JSON.stringify({ version: 1, authority, issuedAt, expiresAt: issuedAt + 60_000 }))
const signature = b64url(createHmac('sha256', Buffer.from(secret, 'base64url')).update(body).digest())
const cookie = `dsh-auth-${b64url(createHash('sha256').update(authority).digest())}=v1.${body}.${signature}`

const req = request({ host: '127.0.0.1', port, path: '/', headers: { host: authority, cookie }, timeout: 4000 }, (res) => {
  res.resume()
  if (res.statusCode === 200) process.exit(0)
  fail(`GET / with a signed session cookie -> HTTP ${res.statusCode}`)
})
req.on('timeout', () => req.destroy(new Error('timed out')))
req.on('error', (error) => fail(`GET / failed: ${error.message}`))
req.end()
