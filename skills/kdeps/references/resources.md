# kdeps Resource Action Reference

Full schemas for resources. A workflow resource has exactly one primary
action: `chat`, `agent`, or `component`. Everything else is a shipped
component called with `component: {name: <component>, with: {...}}`; its
inputs are listed below (from each component's `interface.inputs`).
`apiResponse:` may sit on the same resource to format its output into the
HTTP response. One resource per file (only the first YAML document in a file
is loaded). Common cross-cutting fields (`actionId`, `workflow:` with
`requires`/`items`/`loop`/`onError`, `validations`, `before`, `after`) are at
the end of this file.

## chat (LLM)

Sends a prompt to a language model. Output is a string, or a JSON object when
`jsonResponse: true`. Model goes in the resource; backend and API keys go in
`~/.kdeps/config.yaml` (`llm.backend`, `llm.openai_api_key`, ...).

```yaml
chat:
  model:
    name: llama3.2:1b        # llamafile alias (default file backend: auto-downloaded,
                              # self-served locally), a URL/path to a .llamafile,
                              # or "router" to delegate to config routing.
                              # kdeps llamafile list shows all aliases (-q4/-q6/-q8 quants)
    temperature: 0.7          # 0.0 deterministic .. 2.0 very random
    maxTokens: 1000           # hard cap on generated tokens; 0 = model default
    topP: 0.9                 # nucleus sampling threshold
    frequencyPenalty: 0.0     # -2.0 .. 2.0
    presencePenalty: 0.0      # -2.0 .. 2.0

    timeout: 60s              # hard stop; returns error, does not retry
    streaming: true           # Ollama only; kdeps accumulates chunks before returning

    # Sampling controls (may not be supported by all backends)
    candidateCount: 1         # number of candidate completions to generate
    n: 1                      # alias for candidateCount (OpenAI style)
    minLength: 10             # minimum response length in tokens
    maxLength: 512            # maximum response length (alias for maxTokens)

    # Anthropic-specific
    promptCaching: true       # enable server-side prompt caching (beta header)
    anthropicExtendedOutput: true  # enable 128K output tokens
    anthropicBetaHeaders:     # custom Anthropic beta feature headers
      - "interleaved-thinking-2025-05-14"

    # Google AI / Vertex AI
    googleCachedContent: cachedContents/abc123  # name of a Google AI CachedContent resource
    googleHarmThreshold: 2    # safety filter: 0=unspecified 1=block-none 2=block-few 3=block-some 4=block-most
    googleCloudProject: my-gcp-project   # Vertex AI project ID
    googleCloudLocation: us-central1     # Vertex AI region

    # OpenAI compatibility
    openAILegacyMaxTokens: true  # use max_tokens instead of max_completion_tokens (older servers)

    # Ollama native options (activates native path instead of OpenAI-compat path)
    ollamaThink: true         # enable extended thinking (Ollama 0.9.0+, e.g. deepseek-r1)
    ollamaKeepAlive: 5m       # keep model loaded: "5m", "-1" (indefinite), "0" (unload)
    ollamaPullModel: true     # auto-pull model if not present
    ollamaPullTimeout: 10m    # timeout for model pull
  context:
    role: user                # user, assistant, system
    prompt: "{{ get('q') }}"

    contextLength: 8192       # 4096, 8192, 16384, 32768, 65536, 131072, 262144
    scenario:                 # static conversation prefix known at authoring time
      - role: system
        prompt: You are a helpful assistant.
      - role: assistant
        prompt: I am ready to help!

    messages: "{{ get('history') }}"  # RUNTIME conversation history, evaluated per
                              # request: an array of {role, content} items
                              # ({role, prompt} also accepted) or a JSON-encoded
                              # array string. Roles: system, user, assistant.
                              # Inserted right before the final prompt message.
                              # Requires kdeps from 2026-06-12 or later.

    files:                    # attachments for vision-capable models
      - "{{ get('file', 'filepath') }}"

    fewShot:
      embeddingModel: text-embedding-3-small  # embedding model for semantic few-shot selection
      embeddingBackend: openai                # backend for fewShotEmbeddingModel

    # Per-message cache control (Anthropic only)
    scenario:
      - role: system
        prompt: "You are a helpful assistant."
        cacheControl: ephemeral  # mark this message for server-side caching

  harness:
    output:
      json: true        # ask the model for valid JSON
      keys:         # keys to extract from the JSON response
        - answer
        - confidence

    # Chain-of-thought and few-shot
    chainOfThought: true      # inject a CoT reasoning prefix into the system prompt
  tools:
    list:                    # let the LLM call other resources as functions
      - name: calculate
        description: Perform math
        script: calcResource  # actionId of the resource to invoke
        parameters:
          expression:
            type: string      # string, integer, number, boolean
            description: Math expression
            required: true

    components:           # opt-in allowlist: installed components as tools;
      - scraper               # explicit tools: entries take precedence
      - search

```

Output access: the output is the raw response map -- reply text is at
`get('id').message.content`. With `jsonResponse: true` the output is the
parsed JSON object (`get('id').answer`). Raw response also via
`llm.response('id')`.

Message order sent to the model:
`[scenario system items, system prompt, messages history, prompt]`.
Prefer `messages:` over splicing a transcript string into `prompt:` — it
preserves role structure and avoids prompt injection via fake `Assistant:`
lines.

Caution: `get('history')` resolves memory and session storage **before** the
request body, so a persistent memory key named `history` silently shadows the
request value. Use a distinct name or `input('history')` (strictly request
data) if you also store conversation state server-side.

## http_request (component)

Make an HTTP request through the kdeps API.

```yaml
component:
  name: http_request
  with:
    url: "..."                   # required: URL to request
    method: "..."                # HTTP method (default GET)
    timeout: "..."               # Request timeout, for example 30s
    headers: {}                  # HTTP headers as key-value pairs
    data: {}                     # Request body as JSON (for POST, PUT, PATCH)
    files: {}                    # Multipart form file fields; each value is a file path, data entries become text fields
    failOnError: false           # Treat a non-2xx response as an error instead of returning it
    saveTo: "..."                # Absolute path to stream a 2xx response body into; returns savedTo and bytes
    retry: {}                    # Retry block with maxAttempts, backoff, maxBackoff and retryOn status codes
    cache: {}                    # Cache block with ttl and key; presence enables response caching
    connectionName: "..."        # Named connection in ~/.kdeps/config.yaml supplying auth and proxy
    accountName: "..."           # Named account under the agent identity; resolved as Basic Auth
    followRedirects: false       # Follow redirects; leave unset to follow, false to stop at the first 3xx
    tls: {}                      # TLS block with insecureSkipVerify, certFile, keyFile and caFile
```
## sql (component)

Run SQL against PostgreSQL, MySQL/MariaDB, SQLite, SQL Server or Oracle - one query, or several in a transaction.

```yaml
component:
  name: sql
  with:
    connectionName: "..."       # required: Name under sql_connections in ~/.kdeps/config.yaml (postgres://, mysql://, sqlite://, sqlserver://, oracle://)
    query: "..."                # The statement; placeholders $1, ?, @p1 or :1 all work with every database
    params: []                  # Values for the placeholders, in order
    transaction: false          # Run queries in one transaction (all or nothing)
    queries: []                 # Transaction statements: [{query, params}] or [{query, paramsBatch: [[...], [...]]}]
    format: "..."               # SELECT result shape: '' or table (rows), json (a JSON string), csv
    timeout: "..."              # Statement timeout as a duration (default KDEPS_SQL_TIMEOUT, else 30s)
    maxRows: 0                  # SELECT rows to return at most (default KDEPS_SQL_MAX_ROWS, else 1000)
```
## python (component)

Run a Python script through the kdeps API.

```yaml
component:
  name: python
  with:
    script: "..."              # Inline Python source. Use scriptFile instead to run a file
    scriptFile: "..."          # Path to a .py file. Relative paths resolve against the kdeps process working directory
    args: []                   # Arguments passed to the script after the script path or -c
    env: {}                    # Extra environment variables as key-value pairs; the process environment is inherited
    timeout: "..."             # Hard stop for the script, for example 30s
    venvName: "..."            # Name of a dedicated virtual environment; omit to share the default one
    pythonVersion: "..."       # Python version for the venv; defaults to KDEPS_PYTHON_VERSION, then 3.12
    packages: []               # Python packages installed into the venv before the script runs
```
## exec (component)

Run a shell command through the kdeps API.

```yaml
component:
  name: exec
  with:
    command: "..."          # required: Command to run; sh -c on Unix, cmd /C on Windows, unless args are given
    args: []                # Arguments for command. When set, command runs directly instead of through a shell
    env: {}                 # Extra environment variables as key-value pairs; the process environment is inherited
    workingDir: "..."       # Directory the command runs in. Default: the kdeps process working directory
    timeout: "..."          # Hard stop for the command, for example 30s
```
## file (component)

Structured filesystem operations (read, write, patch, list, delete, exists, mkdir, copy, move, append).

```yaml
component:
  name: file
  with:
    operation: "..."           # required: read, write, patch, list, delete, exists, mkdir, copy, move or append
    path: "..."                # Target file or directory (the destination for copy and move); relative paths resolve against the working directory
    source: "..."              # Source path for copy and move
    content: "..."             # Text to write or append
    patch: "..."               # Unified diff applied by patch
    encoding: "text"           # read output encoding, text or base64
    pattern: "..."             # Glob on entry names for list (e.g. *.go)
    recursive: false           # list walks subdirectories
    backup: false              # write and patch copy the existing file to <path>.bak first
    dryRun: false              # Report what a changing operation would do without doing it
    mode: "..."                # Octal permissions for write (default 0644) and mkdir (default 0755)
    appendNewline: false       # write and append end the content with a newline
```
## git (component)

Structured git operations (status, diff, log, show, branch, remote, add, commit, checkout, init, clone, push, pull).

```yaml
component:
  name: git
  with:
    operation: "..."        # required: status, diff, log, show, branch, remote, add, commit, checkout, init, clone, push or pull
    workingDir: "..."       # Repository directory (clone - the target directory); default the current directory
    paths: "..."            # Space-separated paths for add, checkout, diff, log (add defaults to .)
    message: "..."          # Commit message (commit)
    branch: "..."           # Branch for checkout, push, pull
    url: "..."              # Repository URL (clone)
    remote: "origin"        # Remote for push and pull
    args: "..."             # Extra space-separated git arguments (show)
    maxCount: 10            # Commits to list (log)
    dryRun: false           # Report what a write operation would do without doing it
```
## web_scraper (component)

Fetch a page through the kdeps API.

```yaml
component:
  name: web_scraper
  with:
    url: "..."        # required: Page URL
```
## web_search (component)

Search the web through the kdeps API.

```yaml
component:
  name: web_search
  with:
    query: "..."       # required: Search query
```
## search_local (component)

Search local files through the kdeps API.

```yaml
component:
  name: search_local
  with:
    query: "..."             # Search term. A query or a glob is required
    path: "..."              # Directory to search. Empty searches the working directory
    glob: "..."              # File glob filter, for example *.go
    limit: 3                 # Maximum number of results
    index: false             # Build and use the folder's TF-IDF index for ranked search
    fuzzy: false             # Fuzzy (Levenshtein) matching when index is true
    maxDistance: 2           # Maximum edit distance for fuzzy matching
    indexDBPath: "..."       # Index database path; defaults to the folder's kdeps data dir
    graphBoost: false        # Re-rank indexed results using the folder's reference/topic graph; requires index
```
## embedding (component)

Run one embedding operation through the kdeps API.

```yaml
component:
  name: embedding
  with:
    operation: "..."             # required: index, search, upsert, delete, vectorize, embed_query or rerank
    text: "..."                  # Text to index, search for, upsert or delete
    collection: "..."            # Collection (namespace) inside the local embedding database
    dbPath: "..."                # Path to the SQLite embedding database; defaults come from the embedding defaults
    limit: 0                     # Maximum number of search results
    inputs: []                   # Texts to embed for vectorize and embed_query
    model: "..."                 # Embedding model, for example text-embedding-3-small
    backend: "..."               # Embedding backend: openai, ollama, google
    baseURL: "..."               # Custom base URL for an OpenAI-compatible backend
    rerankQuery: "..."           # Query the candidate documents are ranked against (operation rerank)
    rerankDocuments: []          # Candidate documents to rerank (operation rerank)
    rerankTopN: 0                # Number of top reranked results; 0 returns all
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
  name: web_scraper
  with:
    url: "https://example.com/article"
```

Output access: `output('callerActionId')` -- scoped to the caller, so the same
component can be called from multiple resources independently. When the
component's last resource is `exec`/`python`, the return value is the runner
metadata map; parse structured stdout with `json(get('callerId').result).field`.

Inside component resources, read caller-supplied values with
`get('<componentName>.<input>')` (e.g. `get('web_scraper.url')`). Prefer this over
`input('name')` when the parent workflow also has an HTTP request body — the
expression env exposes `input` as the body map, which shadows the `input()`
function.

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
  statusCode: 200               # optional HTTP status code
  meta:                         # optional _meta override; if a chat resource
    model: llama3.2:1b          # ran, model/backend are added automatically
    backend: file
```

In a bot workflow (`deploy.input.sources: [bot]`), the target resource's
`response` is the reply sent to the platform (or printed in stateless mode).

## Common cross-cutting fields

Available on any resource alongside its action:

```yaml
actionId: myResource        # required; unique across the workflow; key for get()/output()
name: My Resource           # required; human-readable label
description: What it does   # optional
category: api               # optional grouping

workflow:
  requires: [otherResource]   # direct dependencies only; transitive are resolved

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
    code: 400               # becomes the HTTP status; message becomes the body:
    message: "q is required"  # {"error":{"code":"PREFLIGHT_FAILED","message":"q is required"}}
                            # default status without error: is 400.
                            # (kdeps before 2026-06-12 returned a generic 500.)

before:                     # expressions before the action
  - set('full_name', get('first') + ' ' + get('last'))
after:                      # expressions after the action
  - set('summary', get('myResource'))

```

Timeout defaults can be set globally via env vars: `KDEPS_CHAT_TIMEOUT`,
`KDEPS_HTTP_TIMEOUT`, `KDEPS_PYTHON_TIMEOUT`, `KDEPS_EXEC_TIMEOUT`,
`KDEPS_SQL_TIMEOUT`, and `KDEPS_ON_ERROR_ACTION` / `KDEPS_ON_ERROR_MAX_RETRIES`
/ `KDEPS_ON_ERROR_RETRY_DELAY` for error handling.
## vector_store (component)

Run one vector store operation through the kdeps API.

```yaml
component:
  name: vector_store
  with:
    operation: "..."          # required: add_documents or similarity_search
    collection: "..."         # required: Collection, index, or table name in the store
    provider: "..."           # Vector store backend: qdrant (default), chroma, pinecone, azureaisearch, opensearch, elasticsearch, weaviate, pgvector, postgres, alloydb, cloudsql, mariadb, dolt, mysql, mongodb, redis, bedrock
    url: "..."                # Endpoint or DSN for the store
    apiKey: "..."             # Auth token. For mongodb the database name (default kdeps); for opensearch/elasticsearch user:pass
    documents: []             # Documents to upsert for add_documents, each an object with content and optional metadata
    query: "..."              # Natural language search query (operation similarity_search)
    topK: 5                   # Number of results to return for similarity_search
    embedModel: "..."         # Embedding model used to vectorize documents and queries, for example text-embedding-3-small
    embedBackend: "..."       # Embedding provider: openai, ollama, google, or system (follow KDEPS_DEFAULT_BACKEND)
    embedBaseURL: "..."       # Custom base URL for an OpenAI-compatible embedding backend
```
## load_document (component)

Load a document through the kdeps API.

```yaml
component:
  name: load_document
  with:
    source: "..."              # required: Absolute path to the document
    type: "..."                # Document type. Omitted types follow the file extension
    columns: []                # CSV only - optional column filter. Empty loads all columns
    password: "..."            # PDF only - decryption password for encrypted PDFs
    chunkSize: 0               # Split into chunks of this many characters (for RAG). 0 = no splitting
    chunkOverlap: 0            # Characters of overlap between consecutive chunks
    chunkSplitter: "..."       # Splitting strategy when chunkSize is set - recursive (default), token, or markdown
```
## transcribe_audio (component)

Transcribe audio or video through a Whisper API with the kdeps API.

```yaml
component:
  name: transcribe_audio
  with:
    file: "..."                 # required: Absolute path to the audio/video file (mp3, mp4, mpeg, mpga, m4a, wav, webm)
    backend: "openai"           # Provider: openai, groq, or local (a self-hosted OpenAI-compatible Whisper server)
    model: "whisper-1"          # Transcription model (groq uses whisper-large-v3)
    language: "..."             # ISO-639-1 code, e.g. en; empty = auto-detect
    baseURL: "..."              # Overrides the backend API base URL (the .../v1 part)
    prompt: "..."               # Spelling hints for names and terms
    responseFormat: "text"      # text, json, verbose_json, srt or vtt
    temperature: "..."          # Sampling temperature 0-1
```
