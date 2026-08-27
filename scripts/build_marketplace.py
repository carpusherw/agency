#!/usr/bin/env python3
"""Regenerate the `plugins` array of .claude-plugin/marketplace.json from each
plugin's own manifest.

A plugin's manifest is the single source of truth for its name, description,
version, category and tags. The marketplace file is derived, so the two can
never disagree: edit `plugins/<name>/.claude-plugin/plugin.json`, run this, and
commit both.

Top-level marketplace fields ($schema, name, version, description, owner,
metadata) are hand-maintained and preserved. Entry order follows the existing
file; plugins not yet listed are appended in name order.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MARKETPLACE_PATH = REPO_ROOT / ".claude-plugin" / "marketplace.json"
PLUGINS_DIR = REPO_ROOT / "plugins"

REQUIRED_FIELDS = ("name", "description", "version", "category")


def fail(message: str) -> None:
    raise SystemExit(f"build_marketplace: {message}")


def load_manifest(plugin_dir: Path) -> dict:
    path = plugin_dir / ".claude-plugin" / "plugin.json"
    if not path.is_file():
        fail(f"missing {path.relative_to(REPO_ROOT)}")

    with path.open(encoding="utf-8") as handle:
        manifest = json.load(handle)

    missing = [field for field in REQUIRED_FIELDS if field not in manifest]
    if missing:
        fail(f"{path.relative_to(REPO_ROOT)} is missing: {', '.join(missing)}")

    if manifest["name"] != plugin_dir.name:
        fail(
            f"{path.relative_to(REPO_ROOT)} calls itself '{manifest['name']}' "
            f"but lives in '{plugin_dir.name}'"
        )

    return manifest


def entry_for(manifest: dict) -> dict:
    return {
        "name": manifest["name"],
        "description": manifest["description"],
        "source": f"./plugins/{manifest['name']}",
        "version": manifest["version"],
        "category": manifest["category"],
        "tags": list(manifest.get("keywords", [])),
    }


def main() -> int:
    if not MARKETPLACE_PATH.is_file():
        fail(f"{MARKETPLACE_PATH.relative_to(REPO_ROOT)} not found")

    with MARKETPLACE_PATH.open(encoding="utf-8") as handle:
        marketplace = json.load(handle)

    on_disk = {
        path.name
        for path in PLUGINS_DIR.iterdir()
        if path.is_dir() and (path / ".claude-plugin" / "plugin.json").is_file()
    }

    listed = []
    for entry in marketplace.get("plugins", []):
        if not isinstance(entry, dict):
            fail(f"marketplace.json has a plugin entry that is not an object: {entry!r}")
        if "name" not in entry:
            fail(f"marketplace.json has a plugin entry with no name: {entry}")
        if entry["name"] in listed:
            fail(f"marketplace.json lists '{entry['name']}' more than once")
        listed.append(entry["name"])

    vanished = [name for name in listed if name not in on_disk]
    if vanished:
        fail(f"marketplace.json lists plugins that are not on disk: {', '.join(vanished)}")

    ordered = listed + sorted(on_disk - set(listed))
    marketplace["plugins"] = [entry_for(load_manifest(PLUGINS_DIR / n)) for n in ordered]

    MARKETPLACE_PATH.write_text(
        json.dumps(marketplace, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
