#!/usr/bin/env bash
# Verify npx skills add installs only skill content (not tests/ or .github/).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"

echo "Installing kdeps skill from $ROOT into temp project..."
npx skills add "$ROOT" --skill kdeps -y -a cursor --copy

SKILL_DIR="$WORKDIR/.agents/skills/kdeps"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -f "$SKILL_DIR/SKILL.md" ] || fail "missing SKILL.md in installed skill"
[ -d "$SKILL_DIR/references" ] || fail "missing references/ in installed skill"
[ -d "$SKILL_DIR/scripts" ] || fail "missing scripts/ in installed skill"

[ ! -d "$SKILL_DIR/tests" ] || fail "tests/ should not be installed with the skill"
[ ! -d "$SKILL_DIR/.github" ] || fail ".github/ should not be installed with the skill"
[ ! -d "$WORKDIR/tests" ] || fail "repo tests/ should not be copied into install dir"
[ ! -d "$WORKDIR/.github" ] || fail "repo .github/ should not be copied into install dir"

echo "OK: npx skills install contains SKILL.md, references/, scripts/ only"