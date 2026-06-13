# kdeps skill

[![Test fixtures](https://github.com/kdeps/skill/actions/workflows/test.yml/badge.svg)](https://github.com/kdeps/skill/actions/workflows/test.yml)

An [agent skill](https://agentskills.io) that teaches AI coding agents how to
create [kdeps](https://github.com/kdeps/kdeps) components, agents (workflows),
and agencies — with [kdeps.io](https://kdeps.io) registry packaging built in.

## What it covers

- Choosing between a component, an agent, or an agency
- Scaffolding `workflow.yaml`, `component.yaml`, and `agency.yaml`
- Writing resources: all 18 primary actions plus `apiResponse`
- Workflow input (`api`, `bot`, `file`), `webServer`, session, and agent mode
  (`kdeps serve`)
- Components, agencies, expressions, validation, and error handling
- Running, validating, packaging, and publishing (`kdeps run`, `kdeps validate`,
  `kdeps bundle`, `kdeps registry verify`, `kdeps registry submit`)

## Install

```bash
npx skills add https://github.com/kdeps/skill --skill kdeps
```

Use `-y` to skip prompts and `-g` to install globally (available across all
projects).

**Alternative** — clone and copy the skill directory:

```bash
git clone https://github.com/kdeps/skill /tmp/kdeps-skill
cp -r /tmp/kdeps-skill/skills/kdeps ~/.claude/skills/kdeps   # Claude Code
cp -r /tmp/kdeps-skill/skills/kdeps ~/.cursor/skills/kdeps   # Cursor
cp -r /tmp/kdeps-skill/skills/kdeps ~/.grok/skills/kdeps     # Grok
```

The skill activates when you ask the agent to build something with kdeps.

Docs: [kdeps.com/getting-started/agent-skills](https://kdeps.com/getting-started/agent-skills)

## Layout

```
skills/kdeps/               # the agent skill (agentskills.io layout)
  SKILL.md                  # entry point: decision guide + scaffolds
  references/
    resources.md            # full per-action schemas
    expressions.md          # expression functions and operators
    workflow-input.md       # settings.input sources (api, bot, file)
    workflow-settings.md    # apiServer, auth, TLS, agentSettings, session
    registry.md             # kdeps.pkg.yaml and publishing to kdeps.io
  scripts/
    scaffold-pkg.sh         # generate kdeps.pkg.yaml from metadata
tests/                      # CI only — not installed with the skill
  validate.sh               # validate every resource type + component + agency
  npx-skills-install.sh     # verify npx skills add installs skill files only
  check_manifests.py        # kdeps.pkg.yaml vs metadata alignment
  fixtures/                 # minimal workflows used by the test script
```

## Test fixtures

Requires `kdeps` on your PATH:

```bash
./tests/validate.sh          # 81 checks: validate, manifests, registry, bundle, install
./tests/validate.sh --run    # +9 runtime smokes (90 total, 1 skip on older kdeps)
./tests/npx-skills-install.sh
```

CI runs all three on every push to `main`.

| Fixture | What it tests |
|---|---|
| `resources/*` (18) | Each primary resource action + `kdeps.pkg.yaml` |
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
| `components/echo/.../echo` | Standalone component package |
| `workflows/component-caller/.../uppercase` | Standalone component package |