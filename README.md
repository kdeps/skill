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
- Running, validating, and packaging (`kdeps run`, `kdeps validate`,
  `kdeps bundle`)

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
tests/
  validate.sh               # validate every resource type + component + agency
  fixtures/                 # minimal workflows used by the test script
```

## Test fixtures

Requires `kdeps` on your PATH:

```bash
./tests/validate.sh          # schema validation (23 fixtures)
./tests/validate.sh --run    # 9 runtime smoke tests
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
| `agencies/simple` | Two-agent agency + `agent:` resource |
