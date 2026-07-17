---
name: kdeps
description: >
  Create kdeps components, agents (workflows), and agencies. Use when the user
  wants to build a kdeps project, write workflow.yaml, component.yaml, or
  agency.yaml, configure workflow input (api, bot, file), add resources (chat,
  httpClient, sql, python, exec, scraper, searchWeb, botReply, file, git,
  codeIntelligence, apiResponse),
  wire multi-agent pipelines, package/deploy a kdeps app, or publish to kdeps.io.
license: Apache-2.0
metadata:
  author: kdeps
  version: "1.0.0"
---

# kdeps Skill

## Install this skill

```bash
npx skills add https://github.com/kdeps/skill --skill kdeps
```

Use `-y` to skip prompts and `-g` to install globally (available across all
projects).

**Alternative** — clone and copy `skills/kdeps/` into your agent's skills directory:

```bash
git clone https://github.com/kdeps/skill /tmp/kdeps-skill
cp -r /tmp/kdeps-skill/skills/kdeps ~/.claude/skills/kdeps   # Claude Code
cp -r /tmp/kdeps-skill/skills/kdeps ~/.cursor/skills/kdeps   # Cursor
cp -r /tmp/kdeps-skill/skills/kdeps ~/.grok/skills/kdeps     # Grok
```

kdeps builds AI apps from YAML. Two modes:

- **Workflow mode** (`kdeps run`): deterministic DAG pipeline. Resources run in
  dependency order; one resource's output feeds the next; an `apiResponse`
  resource returns the HTTP response.
- **Agent mode** (`kdeps [path]`): interactive LLM REPL. Whole workflows,
  agencies, and components register as callable tools; the LLM routes between
  them. Multi-turn conversation memory, session persistence, skills.

### Agent mode (`kdeps [path]`)

Each workflow becomes one LLM tool named after `metadata.name`. The model reads
from stdin in a REPL, picks tools, and synthesizes a final answer. Individual
resources are never exposed -- only whole workflows, agencies, and installed
components.

```bash
kdeps                                                # model-only REPL, no tools
kdeps ./my-agent/                                    # one workflow = one tool
kdeps ./agents/                                      # every workflow in folder
kdeps ./my-agency/ --model llama3.2 \
  --system "You are a DevOps assistant."
kdeps --skill ~/.kdeps/skills/                       # load skill files
kdeps --resume <session-id>                          # continue a saved session
```

```bash
KDEPS_AGENT_MODEL=claude-3-5-sonnet
KDEPS_AGENT_BACKEND=anthropic
```

REPL slash commands:

| Command | Description |
|---------|-------------|
| `/help` | Show all commands |
| `/clear` | Summarize and clear conversation |
| `/model [name]` | Show or switch LLM model (TUI picker when no arg) |
| `/model default [name]` | Show or persist startup model to `~/.kdeps/agent-loop-settings.yaml` |
| `/models` | List all available models with provider status |
| `/processes` | List running local model servers (llamafile/gguf) with PID, port, health |
| `/processes kill <model>` | Kill a running local model server |
| `/processes switch <model>` | Switch to an already-running local server |
| `/hff search <query>` | Search HuggingFace for GGUF repos (sorted by downloads) |
| `/hff info <repo>` | List GGUF files and sizes in a HuggingFace repo |
| `/hff download <repo> [file]` | Download a GGUF from HuggingFace, register alias, suggest `/model` |
| `/skills` | List loaded skills |
| `/<skill-name> [prompt]` | Invoke a skill or prompt template |
| `/compact` | Summarize history to free context |
| `/history` | Show conversation history |
| `/thinking [off\|low\|medium\|high\|auto]` | Set extended reasoning mode |
| `/session list\|save\|load\|delete\|checkpoint\|goto` | Manage saved sessions |
| `/settings` | Open tool/skill selector |
| `/reload` | Reload skills and prompt templates from disk |
| `/exit` | Exit the REPL |
| `! <cmd>` | Run a shell command; result added to LLM context |
| `!! <cmd>` | Run a shell command without adding to context |

After `/model <local-gguf>`, the REPL blocks with a progress indicator until the
server is fully ready - no network errors on the first prompt.

Sessions are saved as JSONL under `~/.kdeps/sessions/` and resumed with `--resume`.

Opt-in component tools inside a `chat:` resource:

```yaml
chat:
  prompt: "Research {{ get('q') }}"
  componentTools: [scraper, search]
```

Built-in agent tools (always available unless an env var is listed):

| Tool | Requires env var | What it does |
|---|---|---|
| `web_search` (DuckDuckGo) | - | Web search via DuckDuckGo |
| `wikipedia` | - | Wikipedia article lookup |
| `web_scraper` | - | Fetch and clean readable text from a URL |
| `http_request` | - | Call any HTTP API (GET/POST/PUT/DELETE/PATCH) |
| `calculator` | - | Evaluate a math expression (Starlark) |
| `bash_exec` | - | Run a shell command. Ctrl+C interrupts (partial output returned to the model); Ctrl+Z backgrounds it as a job |
| `bash_job_list` | - | List background jobs started via Ctrl+Z |
| `bash_job_wait` | - | Wait for a background job and return its full output |
| `read_file` / `write_file` / `edit_file` / `list_files` | - | Local filesystem: read, write, targeted string edit, list |
| `search_local` | - | ripgrep search across local files (path + query, optional glob) |
| `code_search` / `code_definition` / `code_references` / `code_symbols` / `code_hover` / `code_diagnostics` | - | LSP-powered code intelligence |
| `sql_query` / `sql_list_tables` / `sql_describe_table` | - | Query and introspect a SQLite DB (`KDEPS_SQL_DB_PATH`) |
| `load_document` | - | Load PDF/DOCX/EPUB/HTML/CSV/etc. as text; optional chunking for RAG |
| `embedding_vectorize` / `embedding_search` | - | Index text into the local embedding DB and semantic-search it |
| `memory_save` / `memory_search` / `memory_delete` / `memory_list` | - | Persistent cross-session memory, auto-injected into every call |
| `task_*` / `team_*` | - | Multi-turn task and team orchestration (create, assign, complete, ...) |
| `cron_*` | - | Schedule recurring tasks (create, list, pause, resume, delete) |
| `approval_*` | - | Request/grant/list/revoke one-time permission exceptions |
| `retrieve_context` | `KDEPS_RAG_BASE_URL` | Retrieve chunks from a remote RAG endpoint (only registered when the URL is set) |
| `serpapi_search` | `SERPAPI_API_KEY` | Google Search via SerpAPI |
| `perplexity_search` | `PERPLEXITY_API_KEY` | Cited, up-to-date web answers via Perplexity |
| `exa_search` | `EXA_API_KEY` | Neural web search via Exa (`METAPHOR_API_KEY` also accepted) |
| `wolfram_alpha` | `WOLFRAM_APP_ID` | Wolfram Alpha computation and facts |
| `transcribe_audio` | `OPENAI_API_KEY` / `GROQ_API_KEY` | Whisper transcription (or `local` backend, no key) |
| `cohere_rerank` | `COHERE_API_KEY` | Semantic reranking (Cohere) |
| `voyageai_rerank` | `VOYAGEAI_API_KEY` | Semantic reranking (VoyageAI) |
| `jina_rerank` | `JINA_API_KEY` | Semantic reranking (Jina) |
| `google_cache_create` / `google_cache_delete` / `google_cache_list` | `GOOGLE_API_KEY` | Manage Google AI server-side context caches |
| `zapier_list_actions` / `zapier_run_action` | `ZAPIER_NLA_API_KEY` | Discover and run Zapier NLA actions |

`bash_exec` has no fixed timeout; it runs until completion, Ctrl+C, or Ctrl+Z.
When [rtk](https://github.com/rtk-ai/rtk) is on `PATH`, bash commands are
auto-rewritten through it to cut output tokens (e.g. `git status` runs as
`rtk git status`); set `KDEPS_RTK=off` to disable. `KDEPS_ALLOW_BASH=false`
removes all three `bash_*` tools; `KDEPS_BASH_MODE=read-only` blocks mutating
commands.

`KDEPS_LEAN_MODE=true` strips external-surface tools (bash, web, search, rerank,
http, zapier) for CI/automation, keeping file, code, sql, memory, and
orchestration tools.

For `settings.llm` stdin REPL config, read `references/workflow-input.md`.
For `apiServer` auth, TLS, rate limits, and session, read
`references/workflow-settings.md`.

## What to create

| User wants | Create | Manifests |
|---|---|---|
| A reusable capability callable from any workflow (like a function library) | **Component** | `component.yaml` + `kdeps.pkg.yaml` |
| A single app: API endpoint, pipeline, bot, file processor | **Agent** (workflow) | `workflow.yaml` + `kdeps.pkg.yaml` |
| Multiple cooperating agents that delegate to each other | **Agency** | `agency.yaml` + `kdeps.pkg.yaml` + one `workflow.yaml` per agent |

Rules of thumb:
- One endpoint or one job -> agent.
- "I want to reuse this across projects" or "callable with typed inputs" -> component.
- "Agent A asks agent B" or independent deployable specialists -> agency.

## Universal rules

- Every manifest starts with `apiVersion: kdeps.io/v1` and a `kind:`
  (`Workflow`, `Component`, or `Agency`).
- A resource has exactly **one primary action** (`chat`, `httpClient`, `sql`,
  `python`, `exec`, `email`, `browser`, `scraper`, `searchWeb`, `searchLocal`,
  `embedding`, `telephony`, `botReply`, `agent`, `file`, `git`,
  `codeIntelligence`, `loader`, `vectorStore`, `transcribe`, or `component`).
  `apiResponse:` is not a primary action -- it may sit on the same resource as
  one, formatting that resource's output into the HTTP response.
- One resource per file under `resources/`, **or** inline in `workflow.yaml`
  under a top-level `resources:` list (common in agencies). The loader reads
  only the first YAML document per file -- do not put multiple resources in one
  file separated by `---`.
- Every resource requires both `actionId` (unique across the whole workflow,
  including merged component resources) and `name` (human-readable label).
  Use descriptive camelCase or kebab-case IDs.
- `requires:` lists **direct** dependencies only; kdeps resolves transitive
  ones.
- `metadata.targetActionId` names the resource whose output becomes the
  response. It is required in `workflow.yaml`. Point it at the `apiResponse`
  resource.
- Chat models run on the **file backend (llamafile)** by default:
  `model: llama3.2:1b` is a registry alias, auto-downloaded to
  `~/.kdeps/models` (~1.1 GB once) and self-served locally - no LLM server
  install. `kdeps llamafile list` shows all aliases (quant variants like
  `llama3.2:1b-q6`, `llama3.2:1b-q8`). The **gguf backend** serves GGUF files
  via `llama-server` (llama.cpp): `backend: gguf`, aliases include `qwen3.5-4b`,
  `llama3.2-3b`, `phi4-mini`, `gemma3-4b`, `mistral-7b`, `deepseek-r1-7b`.
  Discover and download any GGUF from HuggingFace directly in the REPL:
  `/hff search llama3` -> `/hff info <repo>` -> `/hff download <repo> <file>` ->
  `/model <alias>`. Uses `HF_TOKEN` env var for gated models.
  Ollama is an explicit opt-in: `installOllama: true` plus
  `agentSettings.env: {KDEPS_DEFAULT_BACKEND: ollama}`.
  Cloud backends: `openai`, `anthropic`, `google`, `mistral`, `groq`, `together`,
  `perplexity`, `cohere`, `deepseek`, `xai` (Grok), `openrouter` (100+ models).
  All configured in `~/.kdeps/config.yaml` under `llm.backend` and the matching
  `*_api_key` field.
- Credentials never go in `workflow.yaml`. SQL DSNs, SMTP/IMAP, HTTP auth, and
  search API keys live in `~/.kdeps/config.yaml`. The API auth token comes from
  `KDEPS_API_AUTH_TOKEN` or `api_auth_token` in `~/.kdeps/config.yaml`.
- **Every distributable project** needs `kdeps.pkg.yaml` at the package root
  (`type: workflow | component | agency`). Version must match `metadata.version`.
  For kdeps.io publishing, read `references/registry.md`.
- Components cannot contain `settings:` (no servers, no ports). They are pure
  resource bundles.
- Every `workflow.yaml` requires a `settings:` block. Internal agency agents
  without a server use a minimal one (e.g. `agentSettings: { timezone: "UTC" }`).
- Expression syntax: `{{ get('key') }}` reads request params or a resource's
  output by actionId; `output('actionId')` reads structured output;
  `set('k', v)` stores a value; `input('name')` reads a component input;
  `env('VAR')` reads an environment variable. For all functions, operators,
  and iteration contexts, read `references/expressions.md`. For workflow input
  sources (`api`, `bot`, `file`), read `references/workflow-input.md`. For
  `apiServer`, auth, TLS, and `agentSettings`, read `references/workflow-settings.md`.

## Creating an agent (workflow)

Structure:

```
my-agent/
|-- kdeps.pkg.yaml         # required for kdeps.io distribution
|-- workflow.yaml
`-- resources/
    |-- llm.yaml
    `-- response.yaml
```

`kdeps.pkg.yaml`:

```yaml
name: my-agent              # must match metadata.name (registry install name)
version: "1.0.0"            # must match metadata.version
type: workflow
description: "What this agent does"
license: Apache-2.0
tags: [llm, api]
```

`workflow.yaml`:

```yaml
apiVersion: kdeps.io/v1
kind: Workflow

metadata:
  name: my-agent            # alphanumeric + hyphens; becomes the tool name in agent mode
  version: "1.0.0"          # semantic version, required
  description: "What this agent does"   # shown to the LLM in agent mode
  targetActionId: response  # resource whose output becomes the HTTP response

settings:
  apiServer:
    hostIp: "127.0.0.1"
    portNum: 16395
    routes:
      - path: /api/v1/chat
        methods: [POST]     # GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
        # public: true      # opt out of bearer auth (browser frontends cannot hold a token)
  # Optional runtime environment (affects local run and Docker builds):
  # agentSettings:
  #   pythonVersion: "3.12"
  #   pythonPackages: [pandas]
  #   osPackages: [ffmpeg]
  #   installOllama: true   # opt-in: bake the ollama server into builds (default backend is llamafile)
  #   env:
  #     SOME_FLAG: "value"    # applies to local runs and Docker; process env wins locally
```

A resource per file under `resources/`:

```yaml
# resources/llm.yaml
actionId: llm
name: LLM Chat
validations:
  methods: [POST]
  routes: [/api/v1/chat]
  check:
    - get('q') != ''        # reject the request if false
  error:
    code: 400
    message: "'q' is required"
chat:
  model: llama3.2:1b        # llamafile alias - auto-downloaded, no LLM server needed
  role: user
  prompt: "{{ get('q') }}"
  timeout: 60s              # hard stop; returns error, does not retry
```

```yaml
# resources/response.yaml
actionId: response
name: API Response
requires: [llm]             # will not run until llm finishes
apiResponse:
  success: true
  response:
    # chat output is the raw response map; reply text is at .message.content
    answer: get('llm').message.content
```

Run and test:

```bash
export KDEPS_API_AUTH_TOKEN=dev-token
kdeps validate workflow.yaml
kdeps run workflow.yaml          # add --dev for hot reload
curl -X POST http://localhost:16395/api/v1/chat \
  -H "Authorization: Bearer $KDEPS_API_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"q": "hello"}'
kdeps registry verify .          # before publishing to kdeps.io
kdeps bundle package .           # -> my-agent-1.0.0.kdeps
```

### Resource action cheat sheet

| Action | Output | Minimal form |
|---|---|---|
| `chat` | response map; text at `.message.content` | `chat: { model: llama3.2:1b, prompt: "..." }` |
| `httpClient` | parsed response body | `httpClient: { method: GET, url: "https://..." }` |
| `sql` | row set | `sql: { connectionName: analytics, query: "SELECT ..." }` |
| `python` | stdout (parsed as JSON) | `python: { script: "print(...)" }` |
| `exec` | stdout | `exec: { command: "echo hi" }` |
| `telephony` | TwiML for voice calls | `telephony: { action: say, say: "Hello" }` |
| `botReply` | reply to bot platform | `botReply: { text: "{{ get('llm') }}" }` |
| `apiResponse` | HTTP response | `apiResponse: { success: true, response: { ... } }` |
| `agent` | target agent's apiResponse | `agent: { name: other-agent, params: { k: v } }` |
| `component` | component result | `component: { name: scraper, with: { url: "..." } }` |
| `scraper` | page text (native) | `scraper: { url: "https://..." }` |
| `searchWeb` | web results | `searchWeb: { query: "...", provider: ddg }` |
| `searchLocal` | file matches | `searchLocal: { path: "/data", glob: "*.txt" }` |
| `embedding` | index/search hits | `embedding: { operation: index, text: "..." }` |
| `file` | result map | `file: { operation: read, path: "/tmp/data" }` |
| `git` | result map | `git: { operation: status, workingDir: "/repo" }` |
| `codeIntelligence` | result map | `codeIntelligence: { operation: symbolSearch, query: "parse", path: "." }` |

Native `scraper`, `searchWeb`, `searchLocal`, and `embedding` require a recent
kdeps release. For PDF/.docx parsing or vector embeddings, install the registry
component instead (`kdeps registry install scraper` / `embedding`).

For the full schema of every action (chat sampling params, httpClient
retry/cache/TLS, sql transactions, email IMAP search, browser actions,
onError), read `references/resources.md`.

Optional per-resource fields: `description`, `category`,
`items:` (run once per list item; read `get('current')`, `get('index')`),
`loop:` (`while:` expression with `maxIterations`, optional `every:`/`at:`),
`before:`/`after:` (expression lists run around the action), and
`validations:` (`methods`/`routes`/`headers`/`params` gates, `skip:` silent
no-op conditions, `check:` + `error:` hard validation).

### LLM tools in a chat resource

```yaml
chat:
  prompt: "Research {{ get('q') }} and summarize."
  componentTools:       # opt-in: expose installed components as function-calling tools
    - scraper
    - search
```

### Multi-turn chat (conversation history)

Pass runtime history as role-tagged messages via `messages:` (kdeps from
2026-06-12 or later) — do not splice a transcript string into the prompt:

```yaml
chat:
  model: llama3.2:1b
  messages: "{{ get('history') }}"  # [{role: user, content: ...}, ...] from the request body
  scenario:
    - role: system
      prompt: You are a helpful, concise assistant.
  prompt: "{{ get('q') }}"
```

The client sends `{"q": "...", "history": [{"role":"user","content":"..."},
{"role":"assistant","content":"..."}]}` and replays the transcript each turn.

### Browser UI in front of the API

Add `webServer` next to `apiServer` in the same workflow. Web routes are
public (no bearer token — browser navigations cannot send one); API routes
stay authenticated. With a distinct `webServer.portNum` the UI gets its own
listener; with the same/omitted port both share the API port. CORS preflights
are answered before auth, so cross-origin `fetch` with `Authorization` also
works. Requires kdeps from 2026-06-12 or later; details and the proxy
`headers:` option in `references/workflow-settings.md`. See
`tests/fixtures/workflows/api-web/`.

### Workflow input

Declare how the workflow receives data via `settings.input`. Valid sources:
`api`, `bot`, `file` — combine them when needed. For the full schema (bot
platform config, file path resolution, combining sources, `settings.llm` REPL),
read `references/workflow-input.md`.

| Source | Use case |
|---|---|
| `api` | HTTP requests to `apiServer` routes (default when `apiServer` is set) |
| `bot` | Discord, Slack, Telegram, WhatsApp (`polling` or `stateless`) |
| `file` | Single-shot: `--file`, stdin, or `KDEPS_FILE_PATH` |

```yaml
# File input — runs once and exits
settings:
  input:
    sources: [file]
    file:
      path: ""
# Resources read get('filePath') and get('fileContent')
```

```yaml
# Stateless bot — stdin JSON in, stdout reply out
settings:
  input:
    sources: [bot]
    bot:
      executionType: stateless
# Use botReply: to send the reply
```

```yaml
# Component-only sub-workflow (no HTTP server)
settings:
  input:
    sources: [api]
  agentSettings:
    pythonVersion: "3.12"
# Invoked via component: from a parent workflow; inputs via with:
```

See `tests/fixtures/workflows/file-input/`,
`tests/fixtures/workflows/component-input/` (api-only sub-workflow),
`tests/fixtures/workflows/component-caller/` (parent + local component),
`tests/fixtures/workflows/llm-repl/` (`kdeps [path]` / stdin REPL),
`tests/fixtures/workflows/session/` (session storage),
`tests/fixtures/workflows/control-flow/` (`items:` + `before:`), and
`tests/fixtures/resources/botReply/`.

### Built-in input component

kdeps ships a pre-installed `input` component (no `kdeps registry install`). It
collects named slots (`query`, `prompt`, `text`, `data`, `key`, `value`, `a`–`h`)
and returns them as JSON:

```yaml
component:
  name: input
  with:
    query: "{{ get('q') }}"
    text: "optional context"
```

See `examples/input-component/` in the kdeps repo.

## Creating a component

**Local use** — auto-discovered from `components/` next to a workflow; no
registration in `workflow.yaml` needed:

```
my-workflow/
|-- workflow.yaml
`-- components/
    `-- greeter/
        |-- component.yaml
        |-- .env              # optional; auto-loaded lowest-priority env vars
        `-- resources/        # optional; resources may also be inline
```

**Registry distribution** — the component directory is the package root:

```
greeter/
|-- kdeps.pkg.yaml
|-- component.yaml
|-- .env              # optional; kdeps registry update scaffolds this
`-- README.md         # optional; kdeps registry update scaffolds this
```

`kdeps.pkg.yaml` for a standalone component:

```yaml
name: greeter
version: "1.0.0"
type: component
description: "A greeting component"
license: Apache-2.0
tags: [greeting]
```

`component.yaml`:

```yaml
apiVersion: kdeps.io/v1
kind: Component
metadata:
  name: greeter               # unique within the workflow
  version: "1.0.0"
  description: "A greeting component"
  targetActionId: greet       # default action when invoked via component:
setup:                        # runs once per engine lifetime (cached)
  pythonPackages: [requests]  # installed via uv pip install
  osPackages: []              # apk / apt-get / brew, auto-detected
  commands: []                # shell commands after installs; non-zero exit = error
teardown:
  commands: []                # best-effort, runs after every invocation
interface:
  inputs:                     # the public contract; types: string, integer, number, boolean
    - name: message
      type: string
      required: true
      description: "Greeting message"
    - name: recipient
      type: string
      required: false
      default: "World"
resources:
  - actionId: greet           # prefix with component name to avoid collisions
    name: Greet
    exec:
      command: "echo '{{ get('greeter.message') }}, {{ get('greeter.recipient') }}!'"
```

Inside component resources, read caller `with:` values via
`get('<componentName>.<input>')`. Use `input('name')` only in component-only
sub-workflows with no HTTP request body (see `references/expressions.md`).

Calling it from a workflow resource:

```yaml
actionId: main
name: Call Greeter
component:
  name: greeter
  with:                       # validated against interface.inputs
    message: "Hello"
    recipient: "KDeps"
```

- Result is read via `output('main')` (the **caller's** actionId). For `exec`/
  `python` components, read structured stdout from `get('main').stdout` or
  `get('main').result`.
- Missing required input = error. Unknown key in `with:` = warning, ignored.
  Omitted optional input = default applied.
- The same component can be called from multiple resources; inputs are scoped
  per caller actionId.
- Env vars resolve as `{COMPONENT_NAME_UPPER}_{VAR}` first, then plain `{VAR}`,
  then the component's `.env` file.

Package and publish:

```bash
kdeps bundle package ./components/greeter   # -> greeter-1.0.0.komponent
kdeps registry verify ./components/greeter  # LLM-agnostic check (no hardcoded secrets)
kdeps registry update ./components/greeter  # scaffold/merge .env and README.md
kdeps registry install scraper              # install registry components
```

To list on kdeps.io: tag a release, run `kdeps registry submit --tag v1.0.0`,
open a PR to `github.com/kdeps/registry`. Full steps in `references/registry.md`.

## Creating an agency

Structure:

```
my-agency/
|-- kdeps.pkg.yaml
|-- agency.yaml
`-- agents/
    |-- greeter/
    |   |-- workflow.yaml     # entry-point agent
    |   `-- resources/
    `-- responder/
        |-- workflow.yaml
        `-- resources/
```

`kdeps.pkg.yaml`:

```yaml
name: my-agency
version: "1.0.0"
type: agency
description: "A multi-agent pipeline"
license: Apache-2.0
tags: [agency, multi-agent]
```

`agency.yaml`:

```yaml
apiVersion: kdeps.io/v1
kind: Agency

metadata:
  name: my-agency
  version: "1.0.0"
  description: "A multi-agent pipeline"
  targetAgentId: greeter-agent   # matches metadata.name in an agent's workflow.yaml;
                                 # omit to use the first discovered agent

# Optional. Omit to auto-discover all agents/**/workflow.yaml and agents/*.kdeps.
agents:
  - agents/greeter
  - agents/responder
```

Each agent is a complete, standalone workflow (own `workflow.yaml`, own
resources, own settings). Only the entry-point agent needs an `apiServer`,
but every agent still needs a `settings:` block -- give internal agents a
minimal one:

```yaml
settings:
  agentSettings:
    timezone: "UTC"
```

Internal agents are called via the `agent:` resource:

```yaml
# inside the entry-point agent's resources/
actionId: delegate
name: Delegate to Responder
agent:
  name: responder-agent          # metadata.name of the target agent
  params:
    text: "{{ get('body') }}"    # readable as get('text') inside the target
```

The caller reads the target's `apiResponse.response` via `output('delegate')`
or `get('delegate')`.

Run, package, and publish:

```bash
kdeps run my-agency/                       # or my-agency/agency.yaml
kdeps registry verify my-agency/             # LLM-agnostic check
kdeps bundle package my-agency/            # -> my-agency-1.0.0.kagency
kdeps bundle build my-agency/ --tag my-agency:latest    # Docker image
kdeps export iso my-agency/                # bootable ISO
kdeps export k8s my-agency/                # Kubernetes manifests
kdeps bundle prepackage my-agency-1.0.0.kagency --output dist/   # single binary
kdeps bundle prepackage my-agency-1.0.0.kagency --include-models  # binary + embedded
                                           # llamafiles: runs fully offline (~1.1 GB/model)
```

Publish to kdeps.io: `references/registry.md`.

## Verify before finishing

Always validate, verify registry readiness, then run:

```bash
kdeps validate .                 # exit 2 = validation error; run from package root
kdeps registry verify .          # exit 1 = hardcoded secrets; WARN = review model names
export KDEPS_API_AUTH_TOKEN=dev-token   # required whenever apiServer is set
kdeps run <path>
```

Confirm `kdeps.pkg.yaml` exists with the correct `type` and matching `version`.
If missing, run `scripts/scaffold-pkg.sh .` from the package root (or write it
from `metadata.name`, `metadata.version`, and the package `type`).
For publishing steps, read `references/registry.md`.

Inline self-tests in `workflow.yaml` or `agency.yaml` (HTTP assertions against
the live server):

```yaml
tests:
  - name: greet returns 200
    request:
      method: GET
      path: /api/v1/greet
      query:
        name: test
    assert:
      status: 200
```

```bash
kdeps run workflow.yaml --self-test-only   # when available: exit 0 = all pass, 1 = failure
```

Run the skill's fixture suite (requires `kdeps` on PATH):

```bash
./tests/validate.sh          # validate, kdeps.pkg.yaml presence, registry verify, bundle
./tests/validate.sh --run    # adds HTTP, bot, file, component, and agency smokes
```

Every fixture package root includes `kdeps.pkg.yaml` — workflows, standalone
components, and agencies are registry-ready by default.

For agent mode testing: `kdeps <path>` (tool name = `metadata.name`).
Use `--debug` to troubleshoot. `kdeps doctor` checks the environment.

## Common mistakes to avoid

- Putting two primary actions in one resource (the validator rejects it;
  only `apiResponse:` may accompany a primary action).
- Putting multiple resources in one file with `---` separators (only the
  first document is loaded).
- Omitting `name:` on a resource (both `actionId` and `name` are required).
- Putting component `name`/`version`/`targetActionId` at the top level of
  `component.yaml` (they belong under `metadata:`).
- Using `{{ inputs.x }}` inside component resources (use `get('<component>.<input>')`
  when called from HTTP workflows; `input('x')` only in component-only sub-workflows).
- Using Jinja2 `{% for %}` over runtime values like `output('id').results` (use
  expression helpers or a `python:` resource instead).
- Using `input('filePath')` for file input source (use `get('filePath')` /
  `get('fileContent')` — see `references/workflow-input.md`).
- Omitting `settings:` on an internal agency agent (every workflow needs one).
- Putting credentials, DSNs, or API keys in `workflow.yaml` (they belong in
  `~/.kdeps/config.yaml`).
- Forgetting `targetActionId` or pointing it at a non-`apiResponse` resource.
- Giving a component a `settings:` block (not allowed).
- Listing transitive dependencies in `requires:` (direct only).
- Forgetting `KDEPS_API_AUTH_TOKEN` when `apiServer` is configured -- kdeps
  refuses to start without it.
- Using dot-notation prose instead of actual YAML when explaining config to
  the user.
- Omitting `kdeps.pkg.yaml` on a project meant for distribution (required for
  `kdeps registry submit` and kdeps.io listing).
- Putting `kdeps.pkg.yaml` in a parent workflow when publishing a standalone
  component (belongs next to `component.yaml`).
- Using `type: agent` in `kdeps.pkg.yaml` (use `type: workflow`).
- Version mismatch between `kdeps.pkg.yaml` and `metadata.version`.
- Splicing a chat transcript string into `prompt:` instead of using
  `messages:` (loses role structure; invites prompt injection via fake
  `Assistant:` lines).
- Reading a request param with `get()` when a persistent memory or session
  key has the same name — memory/session win over the body. Use a distinct
  key or `input('name')` for strictly-request data.
- Targeting an old kdeps for browser-facing features: public web routes,
  honored `webServer.portNum`, CORS preflights, `messages:`, proxy `headers:`,
  and 400 validation responses all require a kdeps build from 2026-06-12 or
  later. Before that, a reverse proxy that injects the bearer token is the
  only way to put a browser UI in front of a kdeps API.

## Reference files

| File | Contents |
|---|---|
| `references/resources.md` | Full schema per resource action |
| `references/expressions.md` | Functions, operators, Jinja2 rules |
| `references/workflow-input.md` | `settings.input` sources (api, bot, file) |
| `references/workflow-settings.md` | `apiServer`, auth, TLS, `agentSettings` |
| `references/registry.md` | `kdeps.pkg.yaml`, verify, bundle, publish to kdeps.io |