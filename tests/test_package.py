from __future__ import annotations

import importlib.util
import hashlib
import json
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NPM = shutil.which("npm.cmd") or shutil.which("npm")


def load_script(name: str):
    path = ROOT / "scripts" / name
    spec = importlib.util.spec_from_file_location(name.removesuffix(".py"), path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


check_package = load_script("check_package.py")
build_release = load_script("build_release.py")


class PackageTests(unittest.TestCase):
    def test_public_package_is_consistent(self):
        errors, warnings = check_package.check()
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_release_file_set_has_runtime_and_excludes_git_state(self):
        files = build_release.iter_files()
        relative = {path.relative_to(ROOT).as_posix() for path in files}
        self.assertIn("SKILL.md", relative)
        self.assertIn("LICENSE", relative)
        self.assertIn("scripts/validate_state.py", relative)
        self.assertIn("scripts/init_project.py", relative)
        self.assertNotIn("scripts/check_package.py", relative)
        self.assertNotIn("scripts/build_release.py", relative)
        self.assertFalse(any(path.startswith(".git/") for path in relative))
        self.assertFalse(any("__pycache__" in path for path in relative))

    def test_npm_manifest_version_matches_the_version_file(self):
        manifest = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        self.assertEqual(manifest["version"], version)

    @unittest.skipUnless(NPM, "npm is unavailable")
    def test_npm_tarball_carries_runtime_and_excludes_repository_tooling(self):
        completed = subprocess.run(
            [NPM, "pack", "--dry-run", "--json"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        packed = {entry["path"] for entry in json.loads(completed.stdout)[0]["files"]}
        for required in (
            "SKILL.md",
            "scripts/init_project.py",
            "scripts/validate_state.py",
            "references/teaching-loop.md",
            "assets/learning-state.template.json",
            "agents/openai.yaml",
            "install.sh",
            "install.ps1",
            "bin/philomatheia.js",
        ):
            self.assertIn(required, packed)
        for excluded in ("scripts/check_package.py", "scripts/build_release.py"):
            self.assertNotIn(excluded, packed)
        self.assertFalse([path for path in packed if path.startswith(("tests/", ".github/"))])

    def test_release_archive_uses_one_top_level_folder(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "release.zip"
            original_argv = build_release.sys.argv
            try:
                build_release.sys.argv = ["build_release.py", "--output", str(output)]
                self.assertEqual(build_release.main(), 0)
            finally:
                build_release.sys.argv = original_argv
            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
            checksum = output.with_suffix(output.suffix + ".sha256")
            recorded = checksum.read_text(encoding="utf-8").split()[0]
            self.assertEqual(recorded, hashlib.sha256(output.read_bytes()).hexdigest())
            self.assertIn("philomatheia/SKILL.md", names)
            self.assertIn("philomatheia/LICENSE", names)
            self.assertTrue(all(name.startswith("philomatheia/") for name in names))


if __name__ == "__main__":
    unittest.main()
