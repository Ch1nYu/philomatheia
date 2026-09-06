# Install Philomatheia

Philomatheia is a standalone Agent Skill. It is a plain directory containing `SKILL.md` plus the reference, asset, and script files it loads on demand. Any agent harness that reads skills from a directory can run it. Nothing in the skill is tied to one vendor or to a built-in installer.

## Where skills live

| Harness | Personal skills directory |
|---|---|
| Codex | `$HOME/.agents/skills` |
| Claude Code | `$HOME/.claude/skills` |
| Anything else | Whatever directory that harness documents |

The installers recognise the first two, but never install into a harness you did not pick. For any other harness, choose the custom entry at the prompt or pass its directory yourself.

## Choosing harnesses

Run with no destination flags and the installer prints what it found and asks:

```text
Select where to install philomatheia. Nothing is selected by default.

  1) Codex        /home/you/.agents/skills  installed
  2) Claude Code  /home/you/.claude/skills  detected, not installed
  3) Another directory (enter the path yourself)

Numbers separated by commas (for example 1,2), or Enter to cancel:
```

Each row carries its own status:

| Status | Meaning |
|---|---|
| `installed` | The skill is already in that directory; installing again replaces it |
| `detected, not installed` | The harness is present on this machine, the skill is not |
| `harness not found` | Neither the harness directory nor the skill exists there |

Enter selects nothing and exits without touching anything. Answer with the numbers you want, separated by commas or spaces; the last entry asks for a directory of your own. If a chosen directory already holds an installation, the installer asks before replacing it.

To see the same table without installing anything, use `--list` or `-ListTargets`.

## With npx

Node 18 or newer is the only requirement, and nothing is cloned:

```sh
npx philomatheia
```

The npm package carries the same runtime files and the same installers; the command only picks the right one for your platform. It accepts one flag surface everywhere, including on Windows:

```sh
npx philomatheia --list
npx philomatheia --all
npx philomatheia --dest-root "$HOME/.config/my-agent/skills"
npx philomatheia --update
npx philomatheia --dry-run
```

Nothing is installed globally. To pin a version, name it: `npx philomatheia@0.2.0`.

## Windows

```powershell
git clone https://github.com/Ch1nYu/philomatheia.git
Set-Location .\philomatheia
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Preview the destinations with `-WhatIf`. Replace an existing installation with the checked-out version by adding `-Update`.

## macOS and Linux

```sh
git clone https://github.com/Ch1nYu/philomatheia.git
cd philomatheia
sh ./install.sh
```

Preview the destinations with `--dry-run`. Replace an existing installation with the checked-out version by adding `--update`.

## Unattended installs

A session that cannot prompt — a pipe, a CI job, or `PHILOMATHEIA_NON_INTERACTIVE=1` — never guesses a destination. It prints the status table and exits with code 2 unless you name the targets:

```sh
sh ./install.sh --all            # every harness already present on this machine
sh ./install.sh --dest-root "$HOME/.claude/skills"
npx philomatheia --all
```

```powershell
pwsh -NoProfile -File .\install.ps1 -All
pwsh -NoProfile -File .\install.ps1 -DestinationRoot "$HOME\.claude\skills"
```

`--all` installs only into harnesses that already exist; it creates nothing for a harness that is absent, and fails when none is found.

## Choosing the destination yourself

Point the installer at any directory:

```sh
sh ./install.sh --dest-root "$HOME/.config/my-agent/skills"
```

```powershell
pwsh -NoProfile -File .\install.ps1 -DestinationRoot "$HOME\.config\my-agent\skills"
```

Repeat `--dest-root` to install into several directories in one run. In PowerShell, pass a comma-separated list and invoke the script with `-Command` rather than `-File`, because `-File` does not split arrays:

```powershell
pwsh -NoProfile -Command "& .\install.ps1 -DestinationRoot '$HOME\.agents\skills','$HOME\.claude\skills'"
```

`PHILOMATHEIA_DEST_ROOT` sets a single destination when no flag is given, and skips the prompt.

## Manual installation

Copy these runtime items into `<skills directory>/philomatheia`:

```text
SKILL.md
agents/
assets/
references/
scripts/init_project.py
scripts/validate_state.py
```

Nothing else is needed at runtime. The tests, package tooling, and repository documentation stay in the clone.

## From a release archive

Tagged releases provide `philomatheia-vX.Y.Z.zip` and a matching `.sha256` on the [GitHub Releases page](https://github.com/Ch1nYu/philomatheia/releases). Verify the checksum, then extract the top-level `philomatheia` folder into your skills directory.

```sh
sha256sum -c philomatheia-v0.2.0.zip.sha256
```

## Verify and use

Confirm the manifest landed:

```sh
cat "$HOME/.claude/skills/philomatheia/SKILL.md" | head -5
```

Most harnesses detect a new skill automatically. Restart the agent if it does not appear. Then open an empty folder for one learning project and ask for what you want to learn:

```text
Use the philomatheia skill. I want to learn statistics well enough to read machine-learning papers critically. Diagnose my current level, then propose the first useful route for my approval.
```

Harnesses that support explicit invocation can call the skill by its name, `philomatheia`. It can also activate on its own when a request matches the learning-focused description in `SKILL.md`.

## Requirements

- Python 3.10 or newer for `init_project.py` and `validate_state.py`
- No third-party Python packages
- PowerShell 7 for the Windows installer, or any POSIX shell elsewhere
- Node.js 18 or newer only for the `npx` entry point; the bundled installers do not need it
