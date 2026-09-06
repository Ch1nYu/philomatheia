from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SH = shutil.which("sh")
PWSH = shutil.which("pwsh")
NODE = shutil.which("node")

# The installer's function block ends where argument parsing begins. Sourcing
# only that block lets a test drive the selection prompt with a stubbed reader.
FUNCTION_BLOCK_END = 'while [ "$#" -gt 0 ]; do'

PS_FUNCTION_BLOCK_END = "if (-not (Test-Path -LiteralPath $sourceManifest"

PS_DRIVER = """param([string]$Functions, [string]$Answers)
$script:queue = [System.Collections.Generic.Queue[string]]::new()
foreach ($answer in ($Answers -split '\\|')) { $script:queue.Enqueue($answer) }
function Read-Host {
    param([string]$Prompt)
    if ($script:queue.Count -eq 0) { return '' }
    return $script:queue.Dequeue()
}
. $Functions
$chosen = @(Select-DestinationRoots)
Write-Output 'SELECTED'
foreach ($root in $chosen) { Write-Output $root }
"""

DRIVER = """. "$1"
answers="$2"
ask() {
    reply=${answers%%|*}
    case "$answers" in
        *"|"*) answers=${answers#*|} ;;
        *) answers="" ;;
    esac
    return 0
}
select_destinations
printf 'SELECTED\\n%s' "$dest_roots"
"""


def sh_environment(home: Path) -> dict[str, str]:
    environment = dict(os.environ)
    environment["HOME"] = str(home)
    environment.pop("PHILOMATHEIA_DEST_ROOT", None)
    environment.pop("PHILOMATHEIA_NON_INTERACTIVE", None)
    return environment


@unittest.skipUnless(SH, "POSIX shell is unavailable")
class PosixInstallerSelectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.directory, True)
        self.home = self.directory / "home"
        (self.home / ".claude").mkdir(parents=True)

        script = (ROOT / "install.sh").read_text(encoding="utf-8")
        block = script.split(FUNCTION_BLOCK_END)[0]
        self.functions = self.directory / "functions.sh"
        self.functions.write_text(block, encoding="utf-8", newline="\n")
        self.driver = self.directory / "driver.sh"
        self.driver.write_text(DRIVER, encoding="utf-8", newline="\n")

        # Git Bash rewrites HOME into a POSIX path, so expectations must use
        # the shell's own view of it rather than the Python one.
        seen = subprocess.run(
            [SH, "-c", 'printf %s "$HOME"'],
            capture_output=True,
            text=True,
            env=sh_environment(self.home),
        )
        self.shell_home = seen.stdout.strip()

    def skills_root(self, marker: str) -> str:
        return f"{self.shell_home}/{marker}/skills"

    def select(self, answers: str) -> list[str]:
        completed = subprocess.run(
            [SH, str(self.driver), str(self.functions), answers],
            capture_output=True,
            text=True,
            env=sh_environment(self.home),
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        body = completed.stdout.split("SELECTED\n", 1)[1]
        return [line for line in body.splitlines() if line]

    def run_installer(self, *arguments: str, home: Path | None = None):
        return subprocess.run(
            [SH, str(ROOT / "install.sh"), *arguments],
            capture_output=True,
            text=True,
            env=sh_environment(home or self.home),
        )

    def test_empty_answer_selects_nothing(self):
        self.assertEqual(self.select(""), [])

    def test_numbers_select_the_listed_harnesses(self):
        chosen = self.select("1,2")
        self.assertEqual(chosen, [self.skills_root(".agents"), self.skills_root(".claude")])

    def test_repeated_choice_is_collapsed(self):
        self.assertEqual(self.select("2 2"), [self.skills_root(".claude")])

    def test_invalid_choice_is_rejected_and_asked_again(self):
        self.assertEqual(self.select("9|abc|2"), [self.skills_root(".claude")])

    def test_last_entry_asks_for_a_custom_directory(self):
        custom = str(self.directory / "custom skills")
        self.assertEqual(self.select("3|" + custom), [custom])

    def test_status_reports_installed_and_missing_harnesses(self):
        listed = self.run_installer("--list")
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertRegex(listed.stdout, r"Codex.*harness not found")
        self.assertRegex(listed.stdout, r"Claude Code.*detected, not installed")

        installed = self.run_installer("--all")
        self.assertEqual(installed.returncode, 0, installed.stderr)
        listed = self.run_installer("--list")
        self.assertRegex(listed.stdout, r"Claude Code.*installed")

    def test_no_destination_is_used_without_a_choice(self):
        environment = sh_environment(self.home)
        environment["PHILOMATHEIA_NON_INTERACTIVE"] = "1"
        completed = subprocess.run(
            [SH, str(ROOT / "install.sh")],
            capture_output=True,
            text=True,
            env=environment,
        )
        self.assertEqual(completed.returncode, 2)
        self.assertIn("cannot prompt", completed.stderr)
        self.assertFalse((self.home / ".claude" / "skills" / "philomatheia").exists())
        self.assertFalse((self.home / ".agents").exists())


@unittest.skipUnless(PWSH and os.name == "nt", "PowerShell 7 on Windows is unavailable")
class WindowsInstallerSelectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.directory, True)
        self.home = self.directory / "home"
        (self.home / ".claude").mkdir(parents=True)

        script = (ROOT / "install.ps1").read_text(encoding="utf-8")
        block = script.split(PS_FUNCTION_BLOCK_END)[0]
        self.functions = self.directory / "functions.ps1"
        self.functions.write_text(block, encoding="utf-8")
        self.driver = self.directory / "driver.ps1"
        self.driver.write_text(PS_DRIVER, encoding="utf-8")

    def select(self, answers: str) -> list[str]:
        environment = dict(os.environ)
        environment["HOME"] = str(self.home)
        environment["USERPROFILE"] = str(self.home)
        completed = subprocess.run(
            [
                PWSH,
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(self.driver),
                str(self.functions),
                answers,
            ],
            capture_output=True,
            text=True,
            env=environment,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        body = completed.stdout.split("SELECTED\n", 1)[1]
        return [line.strip() for line in body.splitlines() if line.strip()]

    def skills_root(self, marker: str) -> str:
        return str(self.home / marker / "skills")

    def test_empty_answer_selects_nothing(self):
        self.assertEqual(self.select(""), [])

    def test_numbers_select_the_listed_harnesses(self):
        self.assertEqual(
            self.select("1,2"),
            [self.skills_root(".agents"), self.skills_root(".claude")],
        )

    def test_repeated_choice_is_collapsed(self):
        self.assertEqual(self.select("2 2"), [self.skills_root(".claude")])

    def test_invalid_choice_is_rejected_and_asked_again(self):
        self.assertEqual(self.select("9|abc|2"), [self.skills_root(".claude")])

    def test_last_entry_asks_for_a_custom_directory(self):
        custom = str(self.directory / "custom skills")
        self.assertEqual(self.select("3|" + custom), [custom])

    def run_installer(self, *arguments: str):
        environment = dict(os.environ)
        environment["HOME"] = str(self.home)
        environment["USERPROFILE"] = str(self.home)
        environment["PHILOMATHEIA_NON_INTERACTIVE"] = "1"
        environment.pop("PHILOMATHEIA_DEST_ROOT", None)
        return subprocess.run(
            [PWSH, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "install.ps1"), *arguments],
            capture_output=True,
            text=True,
            env=environment,
        )

    def test_status_reports_installed_and_missing_harnesses(self):
        listed = self.run_installer("-ListTargets")
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertRegex(listed.stdout, r"Codex.*harness not found")
        self.assertRegex(listed.stdout, r"Claude Code.*detected, not installed")

        installed = self.run_installer("-All")
        self.assertEqual(installed.returncode, 0, installed.stderr)
        listed = self.run_installer("-ListTargets")
        self.assertRegex(listed.stdout, r"Claude Code.*installed")

    def test_no_destination_is_used_without_a_choice(self):
        completed = self.run_installer()
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("cannot prompt", completed.stdout + completed.stderr)
        self.assertFalse((self.home / ".claude" / "skills" / "philomatheia").exists())
        self.assertFalse((self.home / ".agents").exists())


@unittest.skipUnless(NODE, "Node.js is unavailable")
class NpmEntryPointTests(unittest.TestCase):
    """The npx shim offers one flag surface and delegates to the real installer."""

    def setUp(self):
        self.directory = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.directory, True)
        self.home = self.directory / "home"
        (self.home / ".claude").mkdir(parents=True)

    def run_shim(self, *arguments: str):
        environment = dict(os.environ)
        environment["HOME"] = str(self.home)
        environment["USERPROFILE"] = str(self.home)
        environment["PHILOMATHEIA_NON_INTERACTIVE"] = "1"
        environment.pop("PHILOMATHEIA_DEST_ROOT", None)
        return subprocess.run(
            [NODE, str(ROOT / "bin" / "philomatheia.js"), *arguments],
            capture_output=True,
            text=True,
            env=environment,
        )

    def test_posix_flags_work_on_every_platform(self):
        listed = self.run_shim("--list")
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertIn("Claude Code", listed.stdout)
        self.assertIn("detected, not installed", listed.stdout)

    def test_destination_is_installed_and_replacement_needs_update(self):
        destination = self.directory / "skills root"
        installed = self.run_shim("--dest-root", str(destination))
        self.assertEqual(installed.returncode, 0, installed.stderr)
        self.assertTrue((destination / "philomatheia" / "SKILL.md").is_file())
        self.assertFalse((destination / "philomatheia" / "README.md").exists())

        refused = self.run_shim("--dest-root", str(destination))
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("--update", refused.stdout + refused.stderr)

        updated = self.run_shim("--dest-root", str(destination), "--update")
        self.assertEqual(updated.returncode, 0, updated.stderr)

    def test_no_destination_exits_two_without_installing(self):
        completed = self.run_shim()
        self.assertEqual(completed.returncode, 2)
        self.assertIn("--dest-root", completed.stdout + completed.stderr)
        self.assertFalse((self.home / ".claude" / "skills" / "philomatheia").exists())

    def test_unknown_flag_is_refused(self):
        completed = self.run_shim("--nope")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("Unknown option", completed.stderr)


if __name__ == "__main__":
    unittest.main()
