#!/usr/bin/env python3
"""Check that the public Philomatheia repository is internally consistent."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parent.parent
REQUIRED_RUNTIME = (
    "SKILL.md",
    "agents/openai.yaml",
    "assets/learning-state.template.json",
    "assets/LEARNING.template.md",
    "references/domain-routing.md",
    "references/knowledge-graph.md",
    "references/mastery-and-review.md",
    "references/project-state.md",
    "references/source-policy.md",
    "references/teaching-loop.md",
    "scripts/init_project.py",
    "scripts/validate_state.py",
)
REQUIRED_PUBLIC = (
    "README.md",
    "README.zh-TW.md",
    "INSTALL.md",
    "LICENSE",
    "ACKNOWLEDGMENTS.md",
    "EVALUATION.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "SECURITY.md",
    "CHANGELOG.md",
    "PUBLISHING.md",
    "CITATION.cff",
    "VERSION",
    "install.ps1",
    "install.sh",
)
PUBLIC_MARKDOWN = tuple(path for path in REQUIRED_PUBLIC if path.endswith(".md")) + ("SKILL.md",)
LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
NAME_PATTERN = re.compile(r"^[a-z0-9-]{1,64}$")


def frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        raise ValueError("SKILL.md must start with YAML frontmatter")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise ValueError("SKILL.md frontmatter is not closed")
    values: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if not line or line[0].isspace() or ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip("'\"")
    return values


def local_link_target(document: Path, target: str) -> Path | None:
    target = target.strip().strip("<>")
    if not target or target.startswith(("#", "http://", "https://", "mailto:")):
        return None
    target = target.split("#", 1)[0]
    return (document.parent / unquote(target)).resolve()


def check() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    for relative in REQUIRED_RUNTIME + REQUIRED_PUBLIC:
        if not (ROOT / relative).exists():
            errors.append(f"missing required path: {relative}")

    skill_path = ROOT / "SKILL.md"
    if skill_path.exists():
        try:
            metadata = frontmatter(skill_path.read_text(encoding="utf-8"))
        except ValueError as exc:
            errors.append(str(exc))
            metadata = {}
        name = metadata.get("name", "")
        description = metadata.get("description", "")
        if not NAME_PATTERN.fullmatch(name):
            errors.append("SKILL.md name must use lowercase letters, digits, and hyphens")
        if name != ROOT.name:
            errors.append(f"SKILL.md name {name!r} must match folder name {ROOT.name!r}")
        if not description:
            errors.append("SKILL.md description is required")
        elif len(description) > 1024:
            errors.append("SKILL.md description exceeds 1024 characters")

    version_path = ROOT / "VERSION"
    if version_path.exists():
        version = version_path.read_text(encoding="utf-8").strip()
        if not re.fullmatch(r"\d+\.\d+\.\d+", version):
            errors.append("VERSION must contain a semantic version such as 0.1.0")
        for relative in ("README.md", "README.zh-TW.md", "CHANGELOG.md"):
            path = ROOT / relative
            if path.exists() and version not in path.read_text(encoding="utf-8"):
                errors.append(f"{relative} does not mention VERSION {version}")

    template_path = ROOT / "assets/learning-state.template.json"
    if template_path.exists():
        try:
            json.loads(template_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"invalid JSON template: {exc}")

    for relative in PUBLIC_MARKDOWN:
        path = ROOT / relative
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for placeholder in ("YOUR_GITHUB_USERNAME", "YOUR_NAME", "TODO", "TBD"):
            if placeholder in text:
                errors.append(f"{relative} contains unfinished placeholder: {placeholder}")
        for target in LINK_PATTERN.findall(text):
            local_target = local_link_target(path, target)
            if local_target is not None and not local_target.exists():
                errors.append(f"{relative} has broken local link: {target}")

    installer_text = (ROOT / "install.ps1").read_text(encoding="utf-8") if (ROOT / "install.ps1").exists() else ""
    shell_installer_text = (ROOT / "install.sh").read_text(encoding="utf-8") if (ROOT / "install.sh").exists() else ""
    for item in ("SKILL.md", "agents", "assets", "references", "scripts"):
        if item not in installer_text:
            errors.append(f"install.ps1 runtime allowlist is missing {item}")
        if item not in shell_installer_text:
            errors.append(f"install.sh runtime allowlist is missing {item}")

    return errors, warnings


def main() -> int:
    errors, warnings = check()
    print(json.dumps({"ok": not errors, "errors": errors, "warnings": warnings}, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
