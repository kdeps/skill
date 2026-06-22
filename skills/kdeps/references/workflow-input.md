# Workflow Input Reference

`settings.input` declares how a workflow receives data. Combine sources when a
workflow needs multiple entry points (e.g. HTTP API plus a Telegram bot).

## Sources

| Source | When to use | Server/listener started? |
|---|---|---|
| `api` | HTTP requests (default when `apiServer` is set) | Yes, when `apiServer:` is configured |
| `bot` | Discord, Slack, Telegram, WhatsApp | Yes for `polling`; no for `stateless` |
| `file` | Single-shot file processing | No — runs once and exits |

Valid values: `api`, `bot`, `file`. Omit `settings.input` entirely when
`apiServer` handles HTTP and no bot or file input is needed.

### API (HTTP)

Default for workflows with `settings.apiServer`. Request params, headers, JSON
body, and uploads are read via `get('key')`, `input('key')`, or `file('*.pdf')`.

```yaml
settings:
  apiServer:
    portNum: 16395
    routes:
      - path: /api/v1/chat
        methods: [POST]
  # input.sources defaults to api when apiServer is present
```

Callable sub-workflow (no HTTP server — driven by parent `component:` calls):

```yaml
settings:
  agentSettings:
    pythonVersion: "3.12"
  input:
    sources: [api]
# no apiServer block — workflow only runs when invoked via component: from a parent
```

The workflow's `metadata.name` becomes the component name when installed or
referenced. Inputs arrive through the caller's `with:` map and are read with
`input('key')` inside the sub-workflow's resources.

### Bot

Credentials live in `~/.kdeps/config.yaml` under `bot_connections:` (never in
`workflow.yaml`). Platform-specific blocks under `settings.input.bot` configure
polling intervals, guild filters, and webhook ports.

**Polling** (long-running listener):

```yaml
settings:
  input:
    sources: [bot]
    bot:
      executionType: polling   # default
      telegram:
        pollIntervalSeconds: 1
      discord:
        guildId: ""            # optional: restrict to one guild
      slack:
        mode: socket           # default
      whatsApp:
        webhookPort: 16396     # embedded webhook server for Meta Cloud API
```

**Stateless** (one-shot stdin JSON → stdout reply):

```yaml
settings:
  input:
    sources: [bot]
    bot:
      executionType: stateless
```

```bash
echo '{"message":"hello"}' | kdeps run workflow.yaml
```

Use a `botReply:` resource to send the platform reply (or stdout in stateless
mode). Bot webhook fields (`CallSid`, `From`, `SpeechResult`, …) are available
via `get('field')` inside resources.

### File

Single-shot execution. Content is loaded from, in order:

1. `kdeps run workflow.yaml --file /path/to/doc.txt`
2. Stdin (plain text or JSON `{"path":"...","content":"..."}`)
3. `KDEPS_FILE_PATH` environment variable
4. `settings.input.file.path` default

```yaml
settings:
  input:
    sources: [file]
    file:
      path: ""    # optional default when stdin and --file are empty
```

Inside resources, file input populates four body keys:

| Key | Description |
|---|---|
| `path` | Resolved file path |
| `filePath` | Alias of `path` |
| `content` | Full file text |
| `fileContent` | Alias of `content` |

```yaml
apiResponse:
  response:
    path: "{{ get('filePath') }}"
    preview: "{{ get('fileContent') }}"
```

Use `get('filePath')` / `get('fileContent')` for file input body fields.
`input('name')` is for component `with:` parameters and strict request-input
reads in API mode.

```bash
echo "Hello file input" | kdeps run workflow.yaml
kdeps run workflow.yaml --file ./document.txt
KDEPS_FILE_PATH=./doc.txt kdeps run workflow.yaml
```

## Combining sources

```yaml
settings:
  apiServer:
    portNum: 16395
    routes:
      - path: /api/v1/chat
        methods: [POST]
  input:
    sources: [api, bot]
    bot:
      executionType: polling
      telegram:
        pollIntervalSeconds: 2
```

Each source activates its own runner. Resources gate themselves with
`validations.routes` / `validations.methods` when they only apply to one entry
point.

## LLM stdin REPL (`settings.llm`)

Separate from `settings.input` — configures interactive agent-mode REPL when
using `kdeps [path]` or `kdeps run --interactive`:

```yaml
settings:
  input:
    sources: [api]
  llm:
    executionType: stdin       # stdin (default REPL) or apiServer
    prompt: "You: "
    sessionId: llm-chat-session
```

## Reading input in resources

| Function | Use for |
|---|---|
| `get('q')` | Auto-detect: param, body field, prior resource output |
| `input('q')` | Strictly request inputs (params, headers, body, component `with:`) |
| `file('*.pdf')` | Uploaded or local file content by glob |
| `info('path')` | Request metadata: method, path, sessionId, filecount |

Component resources must use `input('name')`, not `inputs.name`.