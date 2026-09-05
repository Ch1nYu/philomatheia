# Install Philomatheia

Philomatheia is a standalone Agent Skill. It is a plain directory containing `SKILL.md` plus the reference, asset, and script files it loads on demand. Any agent harness that reads skills from a directory can run it. Nothing in the skill is tied to one vendor or to a built-in installer.

## Where skills live

| Harness | Personal skills directory |
|---|---|
| Codex | `$HOME/.agents/skills` |
| Claude Code | `$HOME/.claude/skills` |
| Anything else | Whatever directory that harness documents |

The installers detect the first two automatically and install into every one that already exists. For any other harness, pass its directory yourself.

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

`PHILOMATHEIA_DEST_ROOT` sets a single default destination when no flag is given.

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
sha256sum -c philomatheia-v0.1.0.zip.sha256
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
