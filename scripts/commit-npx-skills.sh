#!/usr/bin/env bash
# Run tests and commit the npx skills restructure. Usage: bash scripts/commit-npx-skills.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x tests/npx-skills-install.sh skills/kdeps/scripts/scaffold-pkg.sh

echo "=== npx skills install test ==="
./tests/npx-skills-install.sh

echo
echo "=== validate.sh ==="
./tests/validate.sh

echo
echo "=== git commit ==="
git add -A
git status

if git diff --cached --quiet; then
  echo "Nothing to commit — already up to date?"
  exit 0
fi

git commit -m "feat: restructure for npx skills add compatibility

Move skill to skills/kdeps/ per agentskills.io spec so npx skills add
installs only SKILL.md, references/, and scripts/ (not tests/ or CI).
Add skills.sh.json, npx-skills-install.sh CI test, and npx skills install docs."

git push origin main
echo "Pushed: $(git rev-parse HEAD)"

KDEPS_DOCS="/Users/joel/Projects/cursor/kdeps/docs/v2/getting-started/agent-skills.md"
if [ -f "$KDEPS_DOCS" ]; then
  echo
  echo "=== kdeps docs (if changed) ==="
  (
    cd "$(dirname "$(dirname "$(dirname "$KDEPS_DOCS")")")")"
    git add docs/v2/getting-started/agent-skills.md 2>/dev/null || true
    if ! git diff --cached --quiet 2>/dev/null; then
      git commit -m "docs: fix manual kdeps skill install path for skills/kdeps layout"
      git push origin main
      echo "kdeps pushed: $(git rev-parse HEAD)"
    else
      echo "kdeps docs: no changes to commit"
    fi
  )
fi

echo
echo "Done. Install with:"
echo "  npx skills add https://github.com/kdeps/skill --skill kdeps"