#!/usr/bin/env python3
"""Build a versioned Philomatheia release archive with a single top-level folder."""

from __future__ import annotations

import argparse
import hashlib
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RUNTIME_ITEMS = ("SKILL.md", "agents", "assets", "references")
# Only the scripts the skill loads at runtime. Package tooling stays in the
# clone, as INSTALL.md promises and as both installers already enforce.
RUNTIME_SCRIPTS = ("scripts/init_project.py", "scripts/validate_state.py")
PUBLIC_FILES = (
    "README.md",
    "README.zh-TW.md",
    "INSTALL.md",
    "LICENSE",
    "ACKNOWLEDGMENTS.md",
    "EVALUATION.md",
    "CODE_OF_CONDUCT.md",
    "SECURITY.md",
    "CHANGELOG.md",
    "CITATION.cff",
    "VERSION",
    "install.ps1",
    "install.sh",
)


def release_file(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    return (
        path.is_file()
        and "__pycache__" not in relative.parts
        and path.suffix not in {".pyc", ".pyo"}
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Output zip path")
    return parser.parse_args()


def iter_files() -> list[Path]:
    files: set[Path] = set()
    for item in RUNTIME_ITEMS:
        path = ROOT / item
        if path.is_file():
            files.add(path)
        elif path.is_dir():
            files.update(candidate for candidate in path.rglob("*") if release_file(candidate))
    files.update(ROOT / name for name in RUNTIME_SCRIPTS if (ROOT / name).is_file())
    files.update(ROOT / name for name in PUBLIC_FILES if (ROOT / name).is_file())
    return sorted(files, key=lambda path: path.relative_to(ROOT).as_posix())


def main() -> int:
    args = parse_args()
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    output = args.output or ROOT / "dist" / f"philomatheia-v{version}.zip"
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    files = iter_files()
    required = {ROOT / "SKILL.md", ROOT / "LICENSE", ROOT / "VERSION"}
    if not required.issubset(files):
        missing = ", ".join(str(path.relative_to(ROOT)) for path in sorted(required - set(files)))
        print(f"missing required release files: {missing}", file=sys.stderr)
        return 1

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            relative = Path("philomatheia") / path.relative_to(ROOT)
            archive.write(path, relative.as_posix())

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    checksum = output.with_suffix(output.suffix + ".sha256")
    checksum.write_text(f"{digest}  {output.name}\n", encoding="utf-8")
    print(output)
    print(checksum)
    return 0


if __name__ == "__main__":
    sys.exit(main())
