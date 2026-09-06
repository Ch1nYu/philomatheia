# Install Philomatheia

Philomatheia is a standalone Agent Skill: a plain directory containing `SKILL.md` plus the reference, asset, and script files it loads on demand. Any agent that reads [Agent Skills](https://agentskills.io/) from a directory can run it.

The fastest path needs Node 18 or newer and no clone:

```sh
npx philomatheia
```

It lists the agents it knows about, marks which ones are on your machine, and installs only for the ones you pick.

## Choosing agents

```text
Select where to install philomatheia. Nothing is selected by default.

     AGENT                     STATUS
  1) Claude Code               installed
  2) Codex CLI                 found, not installed
  3) Cursor                    found, not installed
  4) Gemini CLI                not found
  5) GitHub Copilot / VS Code  not found
  6) OpenCode                  found, not installed
  7) Amp                       not found
  8) Goose                     not found
  9) Roo Code                  not found
 10) Factory droid             not found
 11) pi                        not found
 12) OpenClaw                  not found

 13) This project only (./.agents/skills)
 14) Another directory (enter the path yourself)

Numbers separated by commas (for example 1,2), or Enter to cancel: 2,3
```

Each row carries its own status:

| Status | Meaning |
|---|---|
| `installed` | The directory this agent reads already holds the skill |
| `found, not installed` | The agent is on this machine, the skill is not |
| `not found` | The agent's configuration directory is absent — you can still select it |

Enter selects nothing and exits without touching anything. Answer with the numbers you want, separated by commas or spaces. If a chosen directory already holds an installation, the installer asks before replacing it.

## One directory, many agents

Most agents read the same cross-agent directory, so choosing several of them writes once:

```text
Installed philomatheia at /home/you/.agents/skills/philomatheia
  serves Codex CLI, Cursor
```

Three directories cover the whole list. Each mapping comes from that agent's own documentation:

| Directory | Agents that read it |
|---|---|
| `$HOME/.agents/skills` | Codex CLI, Cursor, Gemini CLI, GitHub Copilot / VS Code, OpenCode, Roo Code, Factory droid, pi, OpenClaw |
| `$HOME/.claude/skills` | Claude Code |
| `$XDG_CONFIG_HOME/agents/skills` (`~/.config/agents/skills`) | Amp, Goose |

Several of these agents read more than one location; the installer writes to the one each agent's documentation names first, so a single copy is enough.

## Naming agents directly

Skip the prompt with `--agent`, repeated as needed:

```sh
npx philomatheia --agent claude-code --agent codex
sh ./install.sh --agent cursor
```

```powershell
pwsh -NoProfile -Command "& .\install.ps1 -Agent claude-code,codex"
```

| Name | Agent |
|---|---|
| `claude-code` | Claude Code |
| `codex` | Codex CLI |
| `cursor` | Cursor |
| `gemini` | Gemini CLI |
| `copilot` | GitHub Copilot / VS Code |
| `opencode` | OpenCode |
| `amp` | Amp |
| `goose` | Goose |
| `roo` | Roo Code |
| `factory` | Factory droid |
| `pi` | pi |
| `openclaw` | OpenClaw |

To see the status table without installing anything, use `--list` (or `-ListTargets` in PowerShell).

## With npx

Node 18 or newer is the only requirement, and nothing is cloned or installed globally:

```sh
npx philomatheia
npx philomatheia --list
npx philomatheia --agent codex
npx philomatheia --all
npx philomatheia --dest-root "$HOME/.config/my-agent/skills"
npx philomatheia --update
npx philomatheia --dry-run
```

The npm package carries the same runtime files and the same installers; the command only picks the right one for your platform, and takes the same flags everywhere including Windows. To pin a version, name it: `npx philomatheia@0.3.0`.

## From a clone

```powershell
git clone https://github.com/Ch1nYu/philomatheia.git
Set-Location .\philomatheia
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

```sh
git clone https://github.com/Ch1nYu/philomatheia.git
cd philomatheia
sh ./install.sh
```

Preview with `--dry-run` or `-WhatIf`. Replace an existing installation with `--update` or `-Update`.

## Unattended installs

A session that cannot prompt — a pipe, a CI job, or `PHILOMATHEIA_NON_INTERACTIVE=1` — never guesses. It prints the status table and exits with code 2 unless you name what to install:

```sh
sh ./install.sh --all               # every agent found on this machine
sh ./install.sh --agent claude-code
sh ./install.sh --dest-root "$HOME/.claude/skills"
```

```powershell
pwsh -NoProfile -File .\install.ps1 -All
pwsh -NoProfile -File .\install.ps1 -Agent claude-code
pwsh -NoProfile -File .\install.ps1 -DestinationRoot "$HOME\.claude\skills"
```

`--all` selects only agents whose configuration directory exists, creates nothing for an agent that is absent, and fails when none is found.

## Choosing the destination yourself

For an agent this installer does not know, point it at any directory:

```sh
sh ./install.sh --dest-root "$HOME/.config/my-agent/skills"
```

```powershell
pwsh -NoProfile -File .\install.ps1 -DestinationRoot "$HOME\.config\my-agent\skills"
```

Repeat `--dest-root` for several directories in one run. In PowerShell, pass a comma-separated list and invoke the script with `-Command` rather than `-File`, because `-File` does not split arrays:

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
sha256sum -c philomatheia-v0.3.0.zip.sha256
```

## Verify and use

Confirm the manifest landed:

```sh
cat "$HOME/.agents/skills/philomatheia/SKILL.md" | head -5
```

Most agents detect a new skill automatically. Restart the agent if it does not appear. Then open an empty folder for one learning project and ask for what you want to learn:

```text
Use the philomatheia skill. I want to learn statistics well enough to read machine-learning papers critically. Diagnose my current level, then propose the first useful route for my approval.
```

Agents that support explicit invocation can call the skill by its name, `philomatheia`. It can also activate on its own when a request matches the learning-focused description in `SKILL.md`.

## Requirements

- Python 3.10 or newer for `init_project.py` and `validate_state.py`
- No third-party Python packages
- PowerShell 7 for the Windows installer, or any POSIX shell elsewhere
- Node.js 18 or newer only for the `npx` entry point; the bundled installers do not need it
