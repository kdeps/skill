#!/usr/bin/env bash
# Create or refresh kdeps.pkg.yaml from workflow.yaml, component.yaml, or agency.yaml.
# Usage: scripts/scaffold-pkg.sh [package-directory]
set -euo pipefail

DIR="${1:-.}"
DIR="$(cd "$DIR" && pwd)"

python3 - "$DIR" <<'PY'
import sys
from pathlib import Path

import yaml

pkg_dir = Path(sys.argv[1])
kind_file = None
kind = None
for k, fname in (
    ("workflow", "workflow.yaml"),
    ("agency", "agency.yaml"),
    ("component", "component.yaml"),
):
    if (pkg_dir / fname).exists():
        kind, kind_file = k, pkg_dir / fname
        break

if not kind:
    print(
        f"error: no workflow.yaml, agency.yaml, or component.yaml in {pkg_dir}",
        file=sys.stderr,
    )
    sys.exit(1)

meta = yaml.safe_load(kind_file.read_text()).get("metadata", {})
name = meta.get("name")
version = meta.get("version")
description = meta.get("description", "")

if not name or not version:
    print("error: metadata.name and metadata.version are required", file=sys.stderr)
    sys.exit(1)

manifest = {
    "name": name,
    "version": str(version),
    "type": kind,
    "description": description,
    "license": "Apache-2.0",
    "tags": [kind],
}

out = pkg_dir / "kdeps.pkg.yaml"
out.write_text(yaml.dump(manifest, sort_keys=False, default_flow_style=False))
print(f"Wrote {out}")
PY