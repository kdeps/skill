# kdeps skill

An [agent skill](https://code.claude.com/docs/en/skills) that teaches AI
coding agents how to create [kdeps](https://github.com/kdeps/kdeps)
components, agents (workflows), and agencies.

## What it covers

- Choosing between a component, an agent, or an agency
- Scaffolding `workflow.yaml`, `component.yaml`, and `agency.yaml`
- Writing resources: `chat`, `httpClient`, `sql`, `python`, `exec`, `email`,
  `browser`, `scraper`, `searchWeb`, `searchLocal`, `embedding`, `agent`,
  `component`, `apiResponse`
- Expressions, validation, iteration, and error handling
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
./tests/validate.sh          # schema validation (21 fixtures)
./tests/validate.sh --run    # 7 runtime smoke tests (HTTP, bot, file, agency, components, webserver)
```

CI runs `./tests/validate.sh` on every push to `main`.

The script validates one fixture per primary resource action (`chat`,
`httpClient`, `sql`, `python`, `exec`, `email`, `browser`, `scraper`,
`searchWeb`, `searchLocal`, `embedding`, `telephony`, `botReply`), plus
component invocation, inline resources, file input, and a two-agent agency.
