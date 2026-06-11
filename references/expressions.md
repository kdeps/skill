# kdeps Expression Reference

Functions and operators usable in any field that supports `{{ }}`
interpolation and in expression lists (`before:`, `after:`,
`validations.check`, `validations.skip`, `onError.expr`, `onError.when`).

## Jinja2 preprocessing

Workflow and resource YAML files are preprocessed with Jinja2 **before** YAML
parsing. Use `{% if env.FEATURE == 'true' %}` for build-time conditionals and
`{{ env.PORT | int }}` for environment-driven values.

kdeps **auto-protects** runtime calls (`get`, `set`, `output`, `input`, `info`,
`file`, `json`, etc.) from Jinja2 evaluation — no `{% raw %}` wrapper needed.

**Do not** use Jinja2 `{% for %}` loops over runtime values like
`output('search').results`; Jinja2 runs at parse time when those values do not
exist. Use expression helpers (`map`, `filter`, `join`) or a `python:` resource
instead.

## Core functions

```yaml
get('q')                        # read data, auto-detect source (param, resource output, ...)
get('Authorization', 'header')  # type hints: param, header, session, memory,
get('user_id', 'session')       #   item, env, file, filepath, filetype
get('API_KEY', 'env')
get('limit', '10')              # second positional arg can also be a default value

set('count', 1)                 # store in memory (request-scoped)
set('user', data, 'session')    # store in session (persists across requests;
                                # needs settings.session in workflow.yaml)

output('llmResource')           # output of a completed resource, by actionId;
                                # prefer over get() when auto-detection is ambiguous
input('q')                      # strictly request inputs: param, header, body;
                                # inside component resources, reads interface inputs

file('*.jpg')                   # uploaded/local file content by glob
file('*.pdf', 'first')          # selectors: first, last, count, all, mime:<type>

info('ID')                      # request metadata: ID, IP, timestamp (RFC3339),
info('timestamp')               #   path, method, sessionId, filecount, files, filetypes

session()                       # the entire session data object
env('VAR')                      # environment variable (component-scoped prefix
                                # checked first inside components)
```

## Data handling

```yaml
json(get('userData'))                 # stringify to JSON
safe(user, "profile.address.city")    # nil-safe nested access; nil if path invalid
debug(get('httpResponse'))            # pretty-printed JSON for debugging
default(get('limit'), 10)             # fallback when nil or empty
type(get('value'))                    # "string", "int", "float", "bool", "array", "map", "nil"
int("123")  float("3.14")  string(42) # casting
now()                                 # time.Time value for comparisons
```

## Arrays and strings

```yaml
filter(get('users'), .status == 'active')   # . = current element
map(get('users'), .name)
sum(get('prices'))  min(...)  max(...)
len(get('items'))                           # array or string length
slice(get('items'), 0, 5)                   # negative indices count from end
first(get('items'))  last(get('items'))

lower(s)  upper(s)  trim(s)
split(get('csv'), ',')  join(get('items'), ', ')
replace(get('text'), 'old', 'new')
```

## Operators

Comparison: `==` `!=` `>` `>=` `<` `<=` (aliases: `gt` `gte` `lt` `lte`)

String (infix, not functions):

```yaml
get('text') contains 'urgent'
get('url') startsWith 'https://'
get('file') endsWith '.pdf'
get('email') matches '^[^@]+@[^@]+$'
```

Array: `get('role') in ['admin', 'mod']`, `get('role') notIn ['banned']`,
`get('tags') contains 'featured'`

Logical: `&&`/`and`, `||`/`or`, `!`/`not`

Null and conditionals:

```yaml
get('name') ?? 'Anonymous'              # null coalescing (nil or empty string)
get('name') ?: 'Unknown'                # elvis (left if truthy)
get('score') >= 70 ? 'pass' : 'fail'    # ternary
get('optional') != nil                  # nil check
```

Precedence (highest to lowest): parentheses; unary `!` `-`; `*` `/` `%`;
`+` `-`; comparison; equality; `&&`; `||`; ternary; `??`.

## Iteration context

Inside `items:` resources:

```yaml
item.current()   # or get('current')
item.prev()      # nil on first iteration
item.next()      # nil on last iteration
item.index()     # 0-based; also get('index')
item.count()     # total items
item.values()    # all items as an array
```

Inside `loop:` resources: `loop.index()` (0-based), `loop.count()` (1-based),
`loop.results()` (prior iteration results).

Inside `onError.expr` / `onError.when`: `error.message`, `error.type`.

Inside component resources, caller-supplied `with:` values are injected as
`get('<componentName>.<input>')` (e.g. `get('echo.message')`). Use that form
when the parent workflow has an HTTP body — `input` is also exposed as the
request body map and shadows the `input()` function. For component-only
sub-workflows with no HTTP server, `input('name')` works.

## Resource-specific accessors

```yaml
http.responseBody('id')                  # body only
http.responseHeader('id', 'Content-Type')
exec.exitCode('id')    exec.stderr('id')
python.exitCode('id')  python.stderr('id')
```

## Usage contexts

```yaml
validations:
  check:                          # ALL must be true or the request is rejected
    - get('email') contains '@'
    - len(get('password')) >= 8
  skip:                           # ANY true silently skips the resource
    - get('q') == ''

before:
  - set('isAdmin', get('role') in ['admin', 'superadmin'])
after:
  - set('displayName', get('name') ?? 'Guest')

chat:
  prompt: |                       # {{ }} interpolation in string fields
    User is {{ get('age') >= 18 ? 'adult' : 'minor' }}.
    Role: {{ get('role') ?? 'user' }}.
```

Keep expressions simple -- complex logic belongs in a `python:` resource.
