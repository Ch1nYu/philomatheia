from __future__ import annotations

import importlib.util
import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


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
        self.assertFalse(any(path.startswith(".git/") for path in relative))
        self.assertFalse(any("__pycache__" in path for path in relative))

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
