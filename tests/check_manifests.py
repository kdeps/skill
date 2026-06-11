#!/usr/bin/env python3
"""Verify kdeps.pkg.yaml aligns with workflow.yaml / component.yaml / agency.yaml."""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("error: PyYAML required (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def package_kind(pkg_dir: Path) -> tuple[str, Path] | None:
    for kind, fname in (
        ("workflow", "workflow.yaml"),
        ("agency", "agency.yaml"),
        ("component", "component.yaml"),
    ):
        path = pkg_dir / fname
        if path.exists():
            return kind, path
    return None


def is_package_root(pkg_dir: Path) -> bool:
    rel = str(pkg_dir.relative_to(FIXTURES))
    if rel.startswith("agencies/") and "/agents/" in rel:
        return False
    return package_kind(pkg_dir) is not None


def main() -> int:
    errors: list[str] = []
    checked = 0

    for manifest in sorted(FIXTURES.rglob("kdeps.pkg.yaml")):
        pkg_dir = manifest.parent
        if not is_package_root(pkg_dir):
            continue
        checked += 1
        pkg = yaml.safe_load(manifest.read_text()) or {}
        kind, meta_path = package_kind(pkg_dir)  # type: ignore[misc]
        meta = yaml.safe_load(meta_path.read_text()).get("metadata", {})
        rel = manifest.relative_to(FIXTURES)

        if pkg.get("name") != meta.get("name"):
            errors.append(f"{rel}: name {pkg.get('name')!r} != metadata.name {meta.get('name')!r}")
        if str(pkg.get("version")) != str(meta.get("version")):
            errors.append(
                f"{rel}: version {pkg.get('version')!r} != metadata.version {meta.get('version')!r}"
            )
        if pkg.get("type") != kind:
            errors.append(f"{rel}: type {pkg.get('type')!r} != expected {kind!r}")

    if errors:
        print("Manifest alignment errors:", file=sys.stderr)
        for err in errors:
            print(f"  {err}", file=sys.stderr)
        return 1

    print(f"OK: {checked} kdeps.pkg.yaml files aligned with metadata")
    return 0


if __name__ == "__main__":
    sys.exit(main())