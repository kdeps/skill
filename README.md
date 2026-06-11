# kdeps skill

An [agent skill](https://code.claude.com/docs/en/skills) that teaches AI
coding agents how to create [kdeps](https://github.com/kdeps/kdeps)
components, agents (workflows), and agencies.

## What it covers

- Choosing between a component, an agent, or an agency
- Scaffolding `workflow.yaml`, `component.yaml`, and `agency.yaml`
- Writing resources: all 15 primary actions plus `apiResponse`
- Workflow input (`api`, `bot`, `file`), `webServer`, session, and agent mode
  (`kdeps serve`)
- Components, agencies, expressions, validation, and error handling
- Running, validating, packaging, and publishing (`kdeps run`, `kdeps validate`,
  `kdeps bundle`, `kdeps registry verify`, `kdeps registry submit`)

## Install

```bash
# Claude Code: copy into your skills directory
git clone https://github.com/kdeps/skill ~/.claude/skills/kdeps
```

The skill activates automatically when you ask the agent to build something
with kdeps.

## Layout

```
SKILL.md                    # entry point: decision guide + scaffolds
references/
  resources.md              # full per-action schemas
  expressions.md            # expression functions and operators
  workflow-input.md         # settings.input sources (api, bot, file)
  workflow-settings.md      # apiServer, auth, TLS, agentSettings, session
  registry.md               # kdeps.pkg.yaml and publishing to kdeps.io
scripts/
  scaffold-pkg.sh           # generate kdeps.pkg.yaml from metadata
tests/
  validate.sh               # validate every resource type + component + agency
  check_manifests.py        # kdeps.pkg.yaml vs metadata alignment
  fixtures/                 # minimal workflows used by the test script
```

## Test fixtures

Requires `kdeps` on your PATH:

```bash
./tests/validate.sh          # validate + manifests + registry verify + bundle + install (80 checks)
./tests/validate.sh --run    # adds HTTP, bot, file, component, and agency smokes
```

CI runs `./tests/validate.sh` on every push to `main`.

| Fixture | What it tests |
|---|---|
| `resources/*` (15) | Each primary resource action |
| `components/echo` | Local component + HTTP caller |
| `workflows/inline-resources` | Resources inline in `workflow.yaml` |
| `workflows/file-input` | `input.sources: [file]` |
| `workflows/component-input` | Api-only sub-workflow (no server) |
| `workflows/component-caller` | Parent workflow + `component:` call |
| `workflows/llm-repl` | `settings.llm` stdin REPL (`kdeps serve`) |
| `workflows/webserver` | Static `webServer` |
| `workflows/session` | `settings.session` SQLite config |
| `workflows/control-flow` | `items:` iteration + `before:` expressions |
| `agencies/simple` | Two-agent agency + `agent:` resource + `kdeps.pkg.yaml` |
| `components/echo/.../echo` | Standalone component + `kdeps.pkg.yaml` |
| `workflows/component-caller/.../uppercase` | Standalone component package |
| All `resources/*` and `workflows/*` | Each has `kdeps.pkg.yaml` for kdeps.io packaging |
