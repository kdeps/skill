# kdeps Resource Action Reference

Full per-action schemas for resources. Every resource has exactly one primary
action; `apiResponse:` may additionally sit on the same resource to format its
output into the HTTP response. One resource per file (only the first YAML
document in a file is loaded). All actions work in both workflow mode and
agent mode. Common cross-cutting fields (`actionId`, `requires`,
`validations`, `before`, `after`, `items`, `loop`, `onError`) are at the end
of this file.

## chat (LLM)

Sends a prompt to a language model. Output is a string, or a JSON object when
`jsonResponse: true`. Model goes in the resource; backend and API keys go in
`~/.kdeps/config.yaml` (`llm.backend`, `llm.openai_api_key`, ...).

```yaml
chat:
  model: llama3.2:1b        # model name, or "router" to delegate to config routing
  role: user                # user, assistant, system
  prompt: "{{ get('q') }}"

  contextLength: 8192       # 4096, 8192, 16384, 32768, 65536, 131072, 262144
  temperature: 0.7          # 0.0 deterministic .. 2.0 very random
  maxTokens: 1000           # hard cap on generated tokens; 0 = model default
  topP: 0.9                 # nucleus sampling threshold
  frequencyPenalty: 0.0     # -2.0 .. 2.0
  presencePenalty: 0.0      # -2.0 .. 2.0

  scenario:                 # pre-filled conversation history before the prompt
    - role: system
      prompt: You are a helpful assistant.
    - role: assistant
      prompt: I am ready to help!

  tools:                    # let the LLM call other resources as functions
    - name: calculate
      description: Perform math
      script: calcResource  # actionId of the resource to invoke
      parameters:
        expression:
          type: string      # string, integer, number, boolean
          description: Math expression
          required: true

  componentTools:           # opt-in allowlist: installed components as tools;
    - scraper               # explicit tools: entries take precedence
    - search

  files:                    # attachments for vision-capable models
    - "{{ get('file', 'filepath') }}"

  jsonResponse: true        # ask the model for valid JSON
  jsonResponseKeys:         # keys to extract from the JSON response
    - answer
    - confidence

  timeout: 60s              # hard stop; returns error, does not retry
  streaming: true           # Ollama only; kdeps accumulates chunks before returning
```

Output access: `get('id')` for text, `get('id').answer` when `jsonResponse: true`.

## httpClient

Outbound HTTP request. JSON bodies are parsed automatically; other content
types are stored as a string. Auth and proxy go in `~/.kdeps/config.yaml`
under `http_connections:`, referenced via `connectionName:`.

```yaml
httpClient:
  method: GET                  # GET, POST, PUT, PATCH, DELETE
  url: "https://api.example.com/{{ get('id') }}"
  headers:
    Content-Type: application/json
  data:                        # request body, serialized as JSON
    key: value
  timeout: 30s

  connectionName: stripe       # named connection (auth + proxy)

  retry:
    maxAttempts: 3             # total attempts including the first
    backoff: 1s                # initial wait; doubles each retry
    maxBackoff: 30s
    retryOn: [429, 500, 502, 503, 504]

  cache:                       # presence of cache: enables caching
    ttl: 5m
    key: "custom-cache-key"    # defaults to the URL

  followRedirects: true
  tls:
    insecureSkipVerify: false  # never true in production
    certFile: "/path/cert.pem"
    keyFile: "/path/key.pem"
    caFile: "/path/ca.pem"
```

`http_connections` in `~/.kdeps/config.yaml`: `auth.type` is `basic`
(`username`/`password`), `bearer` (`token`), `api_key` (`key` = header name,
`value` = header value), or `oauth2` (`token`); `proxy` is a proxy URL that
may include `user:pass@`.

Output access: `get('id')` (parsed body), `get('id').statusCode`,
`get('id').headers`, `http.responseBody('id')`, `http.responseHeader('id', 'Content-Type')`.

## sql

Runs SQL against a named connection. DSN lives in `~/.kdeps/config.yaml`
under `sql_connections:`; pool config lives in `workflow.yaml` under
`settings.sqlConnections`. Supports Postgres, MySQL, SQLite, SQL Server, Oracle.

```yaml
sql:
  connectionName: main         # must match a key in sql_connections
  query: "SELECT * FROM users WHERE id = $1"
  params:                      # always parameterize -- never interpolate user input
    - get('user_id')
  format: json                 # json (default), csv, table
  maxRows: 100
  timeout: 30s
```

Transactions and batches (all-or-nothing; rollback on any failure):

```yaml
sql:
  connectionName: main
  transaction: true
  queries:
    - query: "UPDATE accounts SET balance = balance - $1 WHERE id = $2"
      params: [get('amount'), get('from_account')]
    - query: "INSERT INTO products (name, price) VALUES ($1, $2)"
      paramsBatch: "{{ get('products') }}"   # array of parameter arrays
```

Output access: `get('id')` (row array), `get('id')[0].name`.

## python

Runs a Python script; stdout must be valid JSON and becomes the output.
`script` and `scriptFile` are mutually exclusive. Packages come from
`settings.agentSettings.pythonPackages` (installed via uv).

```yaml
python:
  script: |                    # inline; must print JSON to stdout
    import json
    print(json.dumps({"ok": True}))
  scriptFile: "./scripts/process.py"   # alternative: file path; args via sys.argv
  args:
    - "--input"
    - "{{ get('input_file') }}"
  venvName: "my-env"           # resources sharing the same name share packages
  timeout: 60s                 # non-zero exit code counts as failure
```

Output access: `get('id')`, `get('id').field`, `python.exitCode('id')`,
`python.stderr('id')`.

## exec

Runs a shell command; stdout is the output. Echo JSON for structured output.

```yaml
exec:
  command: |                   # supports multiline scripts and {{ }} interpolation
    echo '{"status": "ok"}'
  args: ["--flag", "value"]    # optional
  workingDir: "/tmp"           # optional
  env:                         # optional, this execution only
    TEMP_VAR: "value"
  timeout: 30s
```

Validate user input before interpolating into commands (injection risk):
`check: [get('input') matches '^[a-zA-Z0-9_-]+$']`.

Output access: `get('id')`, `exec.exitCode('id')`, `exec.stderr('id')`.

## email

SMTP send and IMAP read/search/modify. Credentials live in
`~/.kdeps/config.yaml` under `smtp_connections:` / `imap_connections:`
(`host`, `port`, `username`, `password`, `tls`, `insecureSkipVerify`).

```yaml
email:
  action: send            # send (default), read, search, modify
  timeout: 30s

  # send
  smtpConnection: default # required for send
  from: "reports@example.com"
  to: ["alice@example.com"]
  cc: []
  bcc: []
  subject: "Daily Report"
  body: "{{ get('llm') }}"
  html: false             # true = treat body as HTML
  attachments:
    - "/data/reports/q3.pdf"

  # read / search / modify
  imapConnection: inbox   # required for read/search/modify
  mailbox: "INBOX"
  limit: 10
  markRead: false
  search:                 # search action only
    from: "orders@shopify.com"
    to: ""
    subject: "New order"
    body: ""
    since: "2024-01-01"   # ISO date
    before: ""
    unseen: true
    flagged: false
  uids:                   # modify action only
    - "{{ get('findOrders')[0].uid }}"
  modify:                 # modify action only
    markSeen: true
    markFlagged: false
    markDeleted: false
    moveTo: "Processed"
    expunge: false
```

Output: send -> `{success, action, from, to, subject}`; read/search -> array of
`{uid, subject, from, to, date, body, html}`; modify -> `{success, modified}`.

## scraper (native)

Fetches a URL and returns text content, optionally scoped by CSS selector.
For PDFs, .docx, .xlsx, and OCR, install the registry component instead
(`kdeps registry install scraper`).

```yaml
scraper:
  url: "https://example.com"   # required
  selector: "article.content"  # optional CSS selector
  timeout: 30                  # seconds (default 30)
```

Output: `output('id').content`, `.url`, `.status`, `.json`.

## searchWeb (native)

Web search. Default provider is DuckDuckGo (no key needed). Brave, Bing, and
Tavily need an API key in `~/.kdeps/config.yaml` under `search_connections:`.

```yaml
searchWeb:
  query: "{{ get('query') }}"  # required
  provider: ddg                # ddg (default), brave, bing, tavily
  connectionName: brave        # required for brave/bing/tavily
  maxResults: 5
  timeout: 15                  # seconds
```

Output: `output('id').results` (array of `{title, url, snippet}`), `.count`,
`.query`, `.provider`, `.json`.

## searchLocal (native)

Recursive local file search by filename glob and/or content keyword. When both
`query` and `glob` are set, a file must match both.

```yaml
searchLocal:
  path: "/data/documents"   # required: directory to search
  query: "invoice total"    # optional: case-insensitive keyword in contents
  glob: "*.txt"             # optional: filename pattern
  limit: 10                 # 0 = unlimited
```

Output: `output('id').results` (array of `{path, name, size, isDir}`),
`.count`, `.path`, `.json`.

## embedding (native)

SQLite-backed keyword store (LIKE matching, not vector similarity) for
on-prem RAG. For OpenAI vector embeddings, install the registry component
(`kdeps registry install embedding`).

```yaml
embedding:
  operation: "index"               # index, search, upsert, delete
  text: "document content"         # required for index/search/upsert;
                                   # omit on delete to clear the whole collection
  collection: "default"            # namespace
  dbPath: "kdeps-embedding.db"     # SQLite file path
  limit: 10                        # max search results
```

Output: `.operation`, `.collection`, `.success`, `.results` (search),
`.count` (search), `.affected` (delete), `.json`.

## browser

Drives a real browser (Playwright). Requires `npx playwright install chromium`
on the host. Output is the result of the last `evaluate` action, or the final
page URL if none.

```yaml
browser:
  engine: chromium          # chromium (default), firefox, webkit
  url: "https://example.com"
  waitFor: "#username"      # CSS selector to wait for before actions
  headless: true
  sessionId: "user-session" # named persistent context: cookies/storage survive
                            # across resources and API calls
  stealthMode: false        # anti-bot-detection settings
  userAgent: ""             # custom UA string
  viewport:
    width: 1280
    height: 720
  timeout: 30s
  actions:                  # ordered; 16 types: navigate, click, fill, type,
                            # upload, select, check, uncheck, hover, scroll,
                            # press, clear, evaluate, screenshot, wait
    - action: fill
      selector: "#username"
      value: "{{ get('email') }}"
    - action: click
      selector: "button[type='submit']"
    - action: wait
      wait: "3000ms"        # or selector: ".loaded"
    - action: upload
      selector: "#file-input"
      files: ["/tmp/document.pdf"]
    - action: screenshot
      outputFile: /tmp/page.png
      fullPage: true
    - action: evaluate
      script: "document.title"
```

## agent (inter-agent delegation)

Runs another agent's full workflow and returns its `apiResponse.response`.
Used inside agencies.

```yaml
agent:
  name: summariser-agent      # metadata.name in the target's workflow.yaml
  params:                     # readable inside the target via get('key')
    text: "{{ get('body') }}"
```

Output access: `output('callerActionId')` or `get('callerActionId')`.

## component

Invokes a component (custom from `components/` or installed from the
registry). `with:` is validated against the component's `interface.inputs`:
missing required input = error; unknown key = warning, ignored; omitted
optional input = default applied.

```yaml
component:
  name: scraper
  with:
    url: "https://example.com/article"
    selector: ".content"
```

Output access: `output('callerActionId')` -- scoped to the caller, so the same
component can be called from multiple resources independently.

## apiResponse (terminal)

Builds the HTTP response. The last resource in the chain -- the one
`metadata.targetActionId` points at. It can be a standalone resource, or sit
on the same resource as a primary action (formatting that action's output).
In agent mode, `response:` is what the LLM receives as the tool result.

```yaml
apiResponse:
  success: true                 # or an expression: get('op').status == 'success'
  response:                     # any structure; values may be expressions
    answer: get('llm')
    timestamp: info('timestamp')
    request_id: info('ID')
  headers:
    Content-Type: application/json
    X-Total-Count: get('fetchItems').total
  model: llama3.2:1b            # optional metadata override; if a chat resource
  backend: ollama               # ran, model/backend are added automatically
```

## Common cross-cutting fields

Available on any resource alongside its action:

```yaml
actionId: myResource        # required; unique across the workflow; key for get()/output()
name: My Resource           # required; human-readable label
description: What it does   # optional
category: api               # optional grouping

requires: [otherResource]   # direct dependencies only; transitive are resolved

validations:
  methods: [POST]           # gate by request method
  routes: [/api/v1/x]       # gate by route
  headers: [Authorization]  # gate by header presence
  params: [q, limit]        # gate by param presence
  skip:                     # silent no-op when any is true
    - get('mode') == 'fast'
  check:                    # reject the request when any is false
    - get('q') != ''
  error:
    code: 400
    message: "q is required"

before:                     # expressions before the action
  - set('full_name', get('first') + ' ' + get('last'))
after:                      # expressions after the action
  - set('summary', get('myResource'))

items:                      # run once per item; get('current'), get('prev'),
  - "First"                 # get('next'), get('index'), get('count')
  - "Second"

loop:                       # while-loop; loop.index(), loop.count(), loop.results()
  while: "loop.index() < 5"
  maxIterations: 1000       # safety cap (default 1000)
  every: "1s"               # optional delay; mutually exclusive with at
  at: ["09:00"]             # optional schedule (RFC3339, HH:MM, YYYY-MM-DD)

onError:
  action: continue          # continue (use fallback), retry, fail (default)
  maxRetries: 3             # retry only
  retryDelay: "1s"          # retry only
  fallback:                 # continue only: what get('id') returns on failure
    status: "error"
  expr:                     # run when an error is caught
    - set('errorMessage', error.message)
  when:                     # apply onError only if one is true; else propagate
    - error.type == 'TIMEOUT'
    - error.message contains 'connection refused'
```

Timeout defaults can be set globally via env vars: `KDEPS_CHAT_TIMEOUT`,
`KDEPS_HTTP_TIMEOUT`, `KDEPS_PYTHON_TIMEOUT`, `KDEPS_EXEC_TIMEOUT`,
`KDEPS_SQL_TIMEOUT`, and `KDEPS_ON_ERROR_ACTION` / `KDEPS_ON_ERROR_MAX_RETRIES`
/ `KDEPS_ON_ERROR_RETRY_DELAY` for error handling.
