# Publishing to kdeps.io

Every agent (workflow), standalone component, and agency the skill creates must be
**registry-ready**: a `kdeps.pkg.yaml` at the package root, LLM-agnostic YAML,
and a publish path via [kdeps.io](https://kdeps.io).

This skill repo itself is **not** a registry package — it is a coding-agent
skill installed from GitHub. The projects the skill scaffolds **are** registry
packages.

## Package types

| User creates | Manifest `kind` | `kdeps.pkg.yaml` `type` | Archive (`kdeps bundle package`) |
|---|---|---|---|
| Agent (workflow) | `Workflow` | `workflow` | `.kdeps` |
| Standalone component | `Component` | `component` | `.komponent` |
| Agency | `Agency` | `agency` | `.kagency` |

`type` in `kdeps.pkg.yaml` must match the manifest `kind` (lowercase).

## Package root layout

### Workflow (agent)

```
my-agent/
|-- kdeps.pkg.yaml
|-- workflow.yaml
`-- resources/
```

### Standalone component

The **component directory** is the package root — not the parent workflow that
calls it locally.

```
my-component/
|-- kdeps.pkg.yaml
|-- component.yaml
|-- resources/          # optional
|-- .env                # optional; scaffold with kdeps registry update
`-- README.md           # optional; scaffold with kdeps registry update
```

### Agency

```
my-agency/
|-- kdeps.pkg.yaml          # one manifest for the whole agency
|-- agency.yaml
`-- agents/
    |-- greeter/
    |   |-- workflow.yaml   # no separate kdeps.pkg.yaml per sub-agent
    |   `-- resources/
    `-- responder/
        |-- workflow.yaml
        `-- resources/
```

Sub-agents under `agents/` are bundled inside the agency archive — they are not
separate registry packages.

## kdeps.pkg.yaml

Required at the package root for `kdeps registry submit` and
`kdeps registry verify`.

```yaml
name: my-agent              # registry install name (kdeps registry install my-agent)
version: "1.0.0"            # must match metadata.version in workflow.yaml / agency.yaml / component.yaml
type: workflow              # workflow | component | agency
description: "One-line summary shown on kdeps.io"
license: Apache-2.0         # SPDX identifier; recommended
tags:
  - llm
  - api
```

Field rules:

- `name` — lowercase, alphanumeric + hyphens; unique on the registry. **Must
  match `metadata.name`** in the co-located manifest (`workflow.yaml`,
  `component.yaml`, or `agency.yaml`). Official first-party packages may use a
  `kdeps-` prefix in both places.
- `version` — semantic version string; **must match `metadata.version`**.
- `type` — one of `workflow`, `component`, `agency` (validated by the CLI).
- `description` — required for formula submission; shown in search results.

## LLM-agnostic verification

Registry packages must not ship hardcoded secrets. Run before every publish:

```bash
kdeps registry verify .
```

| Finding | Severity | Fix |
|---|---|---|
| Hardcoded `apiKey`, tokens, passwords | ERROR (blocks publish) | Use `env('VAR')` or leave empty |
| Hardcoded `chat.model` | WARN | Omit `model:` so the consumer's `~/.kdeps/config.yaml` provider is used |

Credentials, DSNs, and API keys belong in `~/.kdeps/config.yaml` or environment
variables — never in `workflow.yaml`, `component.yaml`, or `agency.yaml`.

## Local packaging

```bash
kdeps bundle package .       # workflow -> .kdeps, component -> .komponent, agency -> .kagency
kdeps registry install ./my-agent-1.0.0.kdeps   # install from local archive
```

For components, scaffold consumer docs without running the component:

```bash
kdeps registry update ./my-component
```

Creates or merges `.env` (empty template for detected `env()` vars) and
`README.md` from `component.yaml` metadata. Existing files are never
overwritten.

## Publish to kdeps.io

Publishing is GitHub-hosted. The registry indexes formula files; packages live
in the author's repo.

```bash
# 1. Validate
kdeps validate .
kdeps registry verify .

# 2. Tag a release (version must match kdeps.pkg.yaml and metadata.version)
git tag v1.0.0 && git push --tags

# 3. Generate formula YAML (downloads tarball, computes SHA256)
kdeps registry submit --tag v1.0.0

# 4. Open a PR to https://github.com/kdeps/registry
#    Save output as formulas/<name>.yaml
```

After merge, consumers install from anywhere:

```bash
kdeps registry search my-agent
kdeps registry install my-agent
kdeps registry install my-agent@1.0.0
kdeps registry install owner/repo          # directly from GitHub
```

## Checklist before finishing

When scaffolding any distributable project, ensure:

1. `kdeps.pkg.yaml` exists at the package root with correct `type`.
2. `metadata.version` matches `kdeps.pkg.yaml` `version`.
3. `metadata.description` is set (used by agent mode and registry listings).
4. No hardcoded secrets — `kdeps registry verify` passes with zero errors.
5. `kdeps validate` passes on the package root.
6. Optional: `kdeps bundle package` succeeds.
7. Tell the user the publish steps (tag, submit, PR) if they want kdeps.io listing.

## Common mistakes

- Omitting `kdeps.pkg.yaml` (package cannot be submitted to the registry).
- Putting `kdeps.pkg.yaml` in a parent workflow directory when publishing a
  **standalone component** (belongs next to `component.yaml`).
- `type: agent` — invalid; use `type: workflow`.
- Version mismatch between `kdeps.pkg.yaml` and `metadata.version`.
- Hardcoded API keys in YAML (verification ERROR).
- Embedding a component only under `components/` in a workflow without a separate
  `kdeps.pkg.yaml` at the component root when the user wants it installable via
  `kdeps registry install`.