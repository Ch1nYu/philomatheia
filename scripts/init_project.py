#!/usr/bin/env python3
"""Initialize an isolated Philomatheia project without overwriting state."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from string import Template
from typing import Any


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[:8]
    return f"{slug or 'learning-project'}-{digest}"


def replace_tokens(value: Any, replacements: dict[str, Any]) -> Any:
    if isinstance(value, dict):
        return {key: replace_tokens(item, replacements) for key, item in value.items()}
    if isinstance(value, list):
        return [replace_tokens(item, replacements) for item in value]
    if isinstance(value, str) and value in replacements:
        return replacements[value]
    return value


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--title", required=True)
    parser.add_argument("--goal", required=True)
    parser.add_argument("--domain", default="general")
    parser.add_argument("--language", default="zh-TW")
    parser.add_argument("--auto-commit", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    state_dir = root / ".philomatheia"
    state_path = state_dir / "learning-state.json"
    learning_path = state_dir / "LEARNING.md"

    if state_path.exists() or learning_path.exists():
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": "state_exists",
                    "message": "Existing Philomatheia state was preserved.",
                    "state_dir": str(state_dir),
                },
                ensure_ascii=False,
            )
        )
        return 2

    assets = Path(__file__).resolve().parent.parent / "assets"
    raw_state = json.loads((assets / "learning-state.template.json").read_text(encoding="utf-8"))
    md_template = Template((assets / "LEARNING.template.md").read_text(encoding="utf-8"))
    created_at = datetime.now(timezone.utc).isoformat()
    replacements: dict[str, Any] = {
        "__PROJECT_ID__": slugify(args.title),
        "__PROJECT_TITLE__": args.title,
        "__DOMAIN__": args.domain,
        "__LANGUAGE__": args.language,
        "__CREATED_AT__": created_at,
        "__GOAL__": args.goal,
    }
    state = replace_tokens(raw_state, replacements)
    state["project"]["auto_commit"] = args.auto_commit
    learning = md_template.safe_substitute(PROJECT_TITLE=args.title, GOAL=args.goal)

    state_dir.mkdir(parents=True, exist_ok=False)
    (state_dir / "artifacts").mkdir()
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    learning_path.write_text(learning, encoding="utf-8")

    print(
        json.dumps(
            {
                "ok": True,
                "state": str(state_path),
                "learning": str(learning_path),
                "artifacts": str(state_dir / "artifacts"),
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
