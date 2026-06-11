---
name: kdeps
description: >
  Create kdeps components, agents (workflows), and agencies. Use when the user
  wants to build a kdeps project, write workflow.yaml, component.yaml, or
  agency.yaml, add resources (chat, httpClient, sql, python, exec, apiResponse),
  wire multi-agent pipelines, or package/deploy a kdeps app.
---

# kdeps Skill

kdeps builds AI apps from YAML. Two modes:

- **Workflow mode** (`kdeps run`): deterministic DAG pipeline. Resources run in
  dependency order; one resource's output feeds the next; an `apiResponse`
  resource returns the HTTP response.
- **Agent mode** (`kdeps serve`): interactive LLM loop. Whole workflows,
  agencies, and components register as callable tools; the LLM routes between
  them.

## What to create

| User wants | Create | Manifest |
|---|---|---|
| A reusable capability callable from any workflow (like a function library) | **Component** | `component.yaml` |
| A single app: API endpoint, pipeline, bot, file processor | **Agent** (workflow) | `workflow.yaml` |
| Multiple cooperating agents that delegate to each other | **Agency** | `agency.yaml` + one `workflow.yaml` per agent |

Rules of thumb:
- One endpoint or one job -> agent.
- "I want to reuse this across projects" or "callable with typed inputs" -> component.
- "Agent A asks agent B" or independent deployable specialists -> agency.

## Universal rules

- Every manifest starts with `apiVersion: kdeps.io/v1` and a `kind:`
  (`Workflow`, `Component`, or `Agency`).
- A resource has exactly **one primary action** (`chat`, `httpClient`, `sql`,
  `python`, `exec`, `email`, `browser`, `scraper`, `searchWeb`, `searchLocal`,
  `embedding`, `telephony`, `botReply`, `agent`, or `component`).
  `apiResponse:` is not a primary action -- it may sit on the same resource as
  one, formatting that resource's output into the HTTP response.
- One resource per file. The loader reads only the first YAML document in a
  file -- do not put multiple resources in one file separated by `---`.
- Every resource requires both `actionId` (unique across the whole workflow,
  including merged component resources) and `name` (human-readable label).
  Use descriptive camelCase or kebab-case IDs.
- `requires:` lists **direct** dependencies only; kdeps resolves transitive
  ones.
- `metadata.targetActionId` names the resource whose output becomes the
  response. It is required in `workflow.yaml`. Point it at the `apiResponse`
  resource.
- Credentials never go in `workflow.yaml`. SQL DSNs, SMTP/IMAP, HTTP auth, and
  search API keys live in `~/.kdeps/config.yaml`. The API auth token comes from
  `KDEPS_API_AUTH_TOKEN` or `api_auth_token` in `~/.kdeps/config.yaml`.
- Components cannot contain `settings:` (no servers, no ports). They are pure
  resource bundles.
- Every `workflow.yaml` requires a `settings:` block. Internal agency agents
  without a server use a minimal one (e.g. `agentSettings: { timezone: "UTC" }`).
- Expression syntax: `{{ get('key') }}` reads request params or a resource's
  output by actionId; `output('actionId')` reads structured output;
  `set('k', v)` stores a value; `input('name')` reads a component input;
  `env('VAR')` reads an environment variable. For all functions, operators,
  and iteration contexts, read `references/expressions.md`.

## Creating an agent (workflow)

Structure:

```
my-agent/
|-- workflow.yaml
`-- resources/
    |-- llm.yaml
    `-- response.yaml
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
  # Optional runtime environment (affects local run and Docker builds):
  # agentSettings:
  #   pythonVersion: "3.12"
  #   pythonPackages: [pandas]
  #   osPackages: [ffmpeg]
  #   installOllama: true
  #   env:
  #     SOME_FLAG: "value"
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
  model: llama3.2:1b
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

## Creating a component

Structure (auto-discovered from `components/` next to a workflow; no
registration in `workflow.yaml` needed):

```
my-workflow/
|-- workflow.yaml
`-- components/
    `-- greeter/
        |-- component.yaml
        |-- .env              # optional; auto-loaded lowest-priority env vars
        `-- resources/        # optional; resources may also be inline
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
      command: "echo '{{ input('message') }}, {{ input('recipient') }}!'"
```

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

- Result is read via `output('main')` (the **caller's** actionId).
- Missing required input = error. Unknown key in `with:` = warning, ignored.
  Omitted optional input = default applied.
- The same component can be called from multiple resources; inputs are scoped
  per caller actionId.
- Env vars resolve as `{COMPONENT_NAME_UPPER}_{VAR}` first, then plain `{VAR}`,
  then the component's `.env` file.

Package and distribute:

```bash
kdeps bundle package ./components/greeter   # -> greeter-1.0.0.komponent
kdeps registry install scraper              # install registry components
kdeps registry update ./components/greeter  # scaffold/merge .env and README.md
```

## Creating an agency

Structure:

```
my-agency/
|-- agency.yaml
`-- agents/
    |-- greeter/
    |   |-- workflow.yaml     # entry-point agent
    |   `-- resources/
    `-- responder/
        |-- workflow.yaml
        `-- resources/
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

Run and package:

```bash
kdeps run my-agency/                       # or my-agency/agency.yaml
kdeps bundle package my-agency/            # -> my-agency-1.0.0.kagency
kdeps bundle build my-agency/ --tag my-agency:latest    # Docker image
kdeps export iso my-agency/                # bootable ISO
kdeps bundle prepackage my-agency-1.0.0.kagency --output dist/   # single binary
```

## Verify before finishing

Always validate, then run, in this order:

```bash
kdeps validate workflow.yaml     # exit 2 = validation error
export KDEPS_API_AUTH_TOKEN=dev-token   # required whenever apiServer is set
kdeps run <path>
```

For agent mode testing: `kdeps serve <path>` (tool name = `metadata.name`).
Use `--debug` to troubleshoot. `kdeps doctor` checks the environment.

## Common mistakes to avoid

- Putting two primary actions in one resource (the validator rejects it;
  only `apiResponse:` may accompany a primary action).
- Putting multiple resources in one file with `---` separators (only the
  first document is loaded).
- Omitting `name:` on a resource (both `actionId` and `name` are required).
- Putting component `name`/`version`/`targetActionId` at the top level of
  `component.yaml` (they belong under `metadata:`).
- Using `{{ inputs.x }}` inside component resources (the correct form is
  `{{ input('x') }}`).
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
