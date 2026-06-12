# Workflow Settings Reference

`settings:` in `workflow.yaml` configures servers, runtime environment, and
optional features. Every workflow requires a `settings:` block (agency internal
agents may use a minimal one).

## apiServer (HTTP API)

```yaml
settings:
  apiServer:
    hostIp: "127.0.0.1"      # bind address; 0.0.0.0 for all interfaces
    portNum: 16395
    routes:
      - path: /api/v1/chat
        methods: [POST]       # GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
    cors:
      allowedOrigins: ["*"]   # or allowOrigins: [https://myapp.com]
    rateLimit:
      requestsPerMinute: 60
      burst: 10
    maxBodyBytes: 1048576     # 1 MB; 413 when exceeded
    trustedProxies:           # honor X-Forwarded-For only from these CIDRs
      - "10.0.0.0/8"
```

When `apiServer` is set, authentication is **required**. Never put the token in
`workflow.yaml`:

```bash
export KDEPS_API_AUTH_TOKEN=your-secret-token
# or set api_auth_token in ~/.kdeps/config.yaml
```

Clients send `Authorization: Bearer <token>` or `X-Api-Key: <token>`.
`/health` is exempt. `/_kdeps/*` management routes use `KDEPS_MANAGEMENT_TOKEN`.

CORS preflight `OPTIONS` requests are answered before auth (browsers never
attach credentials to preflights), and auth failures carry CORS headers, so
browser clients can call the API cross-origin with a bearer token.
(Requires a kdeps build from 2026-06-12 or later; older releases 401 the
preflight, which blocks all cross-origin browser requests.)

TLS (optional — omit for plain HTTP):

```yaml
settings:
  certFile: /path/to/cert.pem
  keyFile: /path/to/key.pem
  apiServer:
    portNum: 443
```

## webServer (static files / proxy)

Serves static assets or proxies upstream apps. Shares `rateLimit`,
`maxBodyBytes`, and `trustedProxies` with `apiServer`. Workflows that only
serve static files may set `metadata.targetActionId: none`.

```yaml
settings:
  webServer:
    portNum: 8080
    routes:
      - path: /
        serverType: static          # or app (reverse proxy)
        publicPath: ./public
      - path: /upstream
        serverType: app
        appPort: 9000               # proxy target on localhost
        command: "npm start"        # optional: kdeps starts and manages the app
        headers:                    # optional: set/override headers on proxied requests
          Authorization: "Bearer {{ env('UPSTREAM_TOKEN') }}"
```

Web routes are always **public** (no API auth) — a browser navigation cannot
send an `Authorization` header. API routes keep bearer-token auth even when a
wildcard web route like `/` also matches them.

When a workflow has **both** `apiServer` and `webServer`:

- **Different `portNum`** — two listeners: the web server serves its routes on
  its own port with no auth; the API keeps auth on its port.
- **Same or omitted `webServer.portNum`** — one listener: web routes merge onto
  the API port. Static assets stay public; API routes stay authenticated.

This is the pattern for a browser UI in front of a kdeps API: serve the UI
from `webServer`, call the API from the page with the bearer token.
(Public web routes and the honored web port require a kdeps build from
2026-06-12 or later; older releases merge everything onto the API port behind
auth.)

`headers:` values support `{{ env('VAR') }}` interpolation so secrets stay
out of the YAML; configured headers override same-name headers forwarded from
the client. Other expression functions are not evaluated in header values.

See `tests/fixtures/workflows/webserver/` (static only) and
`tests/fixtures/workflows/api-web/` (API + web UI in one workflow).

## agentSettings (runtime environment)

```yaml
settings:
  agentSettings:
    timezone: UTC
    pythonVersion: "3.12"
    pythonPackages: [pandas, requests]
    osPackages: [ffmpeg]
    installOllama: true
    env:
      MY_FLAG: "value"
```

Affects local `kdeps run` and Docker builds. Python packages install via `uv`.

## sqlConnections (pool config)

DSN credentials go in `~/.kdeps/config.yaml` under `sql_connections:`. Pool
settings live in the workflow:

```yaml
settings:
  sqlConnections:
    main:
      driver: postgres
      maxOpen: 10
      maxIdle: 5
```

## session (persistent state)

Omit the block entirely to disable sessions. When present, enables
`set('key', val, 'session')`, `get('key', 'session')`, and `session()` across
requests.

```yaml
settings:
  session:
    type: sqlite              # sqlite (default) or memory
    path: ":memory:"          # SQLite path; default ~/.kdeps/sessions.db
    ttl: 30m                  # session expiration
    cleanupInterval: 5m       # expired session cleanup interval
```

See `tests/fixtures/workflows/session/`.

## input and llm

See `references/workflow-input.md` for `settings.input` (api, bot, file) and
`settings.llm` (stdin REPL for `kdeps serve` / `kdeps run --interactive`).

## Per-agent config overrides

In `~/.kdeps/config.yaml`, override globals per workflow name:

```yaml
agents:
  my-agent:              # matches metadata.name
    llm:
      backend: openai
      openai_api_key: sk-...
```