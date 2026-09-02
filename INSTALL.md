# Install Philomatheia

Philomatheia is a standalone Agent Skill. Codex loads personal skills from `$HOME/.agents/skills`.

## Skill Installer

In Codex, ask the built-in installer to install this repository:

```text
$skill-installer Install the philomatheia skill from https://github.com/Ch1nYu/philomatheia
```

## Windows

```powershell
git clone https://github.com/Ch1nYu/philomatheia.git
Set-Location .\philomatheia
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Preview with `-WhatIf`. Replace an existing installation with the checked-out version by adding `-Update`.

## macOS and Linux

```sh
git clone https://github.com/Ch1nYu/philomatheia.git
cd philomatheia
sh ./install.sh
```

Preview with `--dry-run`. Replace an existing installation with the checked-out version by adding `--update`.

## Manual installation

Copy these runtime items into `$HOME/.agents/skills/philomatheia`:

```text
SKILL.md
agents/
assets/
references/
scripts/
```

Tagged releases also provide a `philomatheia-vX.Y.Z.zip` archive and matching `.sha256` checksum on the [GitHub Releases page](https://github.com/Ch1nYu/philomatheia/releases). Extract the top-level `philomatheia` folder under `$HOME/.agents/skills`.

Codex normally detects new skills automatically. Restart Codex if it does not appear. Then invoke it explicitly:

```text
$philomatheia Help me learn statistics well enough to read machine-learning papers. Diagnose my current level, then propose the first useful route for my approval.
```

The skill can also activate automatically when a request matches the learning-focused description in `SKILL.md`.
