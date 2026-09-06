# Philomatheia

[![Validate](https://github.com/Ch1nYu/philomatheia/actions/workflows/validate.yml/badge.svg)](https://github.com/Ch1nYu/philomatheia/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-open%20standard-blue.svg)](https://agentskills.io/)

**A persistent, evidence-based learning skill that can build a goal-specific curriculum for almost any subject.**

[繁體中文](README.zh-TW.md)

Philomatheia turns a learning goal into a visible knowledge map, teaches through small adaptive loops, records what the learner can actually demonstrate, and resumes from an exact checkpoint across sessions. It runs on any agent harness that loads skills from a directory, including Codex and Claude Code.

> Project status: `v0.3.0` alpha. The state model, validators, and installers are tested. Long-term learning-outcome improvements have not yet been established by a controlled or longitudinal study.

## Why use it

| Common learning workflow | Philomatheia |
|---|---|
| Follows a fixed table of contents | Builds the useful prerequisite trunk around the learner's goal |
| Marks a lesson complete after exposure or a quiz | Tracks recall, explanation, guided use, independent use, and transfer separately |
| Restarts from chat history | Persists an exact, self-contained checkpoint in the project |
| Uses one route for everyone | Adjusts frontier size, representation, hints, and review from observed evidence |
| Hides curriculum assumptions | Records sources for nodes, relationships, and important claims |

Philomatheia is useful when the desired result is durable ability rather than a one-off answer. It deliberately stays out of generic research, ordinary code review, and work completed on the user's behalf without a learning goal.

## Quick start

### Install

With Node 18 or newer, no clone is needed:

```sh
npx philomatheia
```

Or clone the repository and run the installer for your platform:

```powershell
# Windows
git clone https://github.com/Ch1nYu/philomatheia.git
Set-Location .\philomatheia
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

```sh
# macOS or Linux
git clone https://github.com/Ch1nYu/philomatheia.git
cd philomatheia
sh ./install.sh
```

The installer copies only the runtime files, and installs nothing until you choose. It lists the agents it knows about, marks which ones are on your machine, and asks:

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

Installed philomatheia at /home/you/.agents/skills/philomatheia
  serves Codex CLI, Cursor
```

Most agents read the same cross-agent directory, so choosing several of them writes once. Enter selects nothing and leaves the machine untouched.

Skip the prompt with `--agent claude-code`, repeated as needed. `--list` prints the status table without installing, `--all` selects every agent found on this machine, `--dry-run` previews, and `--update` replaces an existing installation. `npx philomatheia` takes the same flags on every platform, Windows included; the bundled `install.ps1` uses `-Agent`, `-ListTargets`, `-All`, `-WhatIf`, `-Update`.

See [INSTALL.md](INSTALL.md) for the full agent list with directories, manual installation, release archives, and agents this installer does not know about.

### Start a learning project

Open your agent in an empty folder dedicated to one learning project, then ask:

```text
Use the philomatheia skill. I want to learn statistics well enough to read machine-learning papers critically. I have four hours per week. Diagnose my current level, then propose the first useful knowledge-map route for my approval.
```

Other examples:

```text
Teach me practical Japanese for ordering food safely with a severe peanut allergy. Separate language practice from claims about food safety.
```

```text
Resume this learning project from its exact checkpoint. Begin with one short recall question and do not repeat completed material.
```

Harnesses that support explicit invocation can call the skill by name, `philomatheia`. It also activates on its own when the request matches the learning-oriented description in [SKILL.md](SKILL.md).

## How it works

```text
goal and constraints
        |
        v
approved goal subgraph and completion contract
        |
        v
2-3 node active frontier, or 1 when load requires it
        |
        v
retrieve -> explain -> predict -> practise -> verify -> integrate
        |
        v
evidence, mastery, review, and exact checkpoint
        |
        +---------------------> next spiral pass
```

Each learning project owns a `.philomatheia/` directory:

```text
.philomatheia/
|-- learning-state.json   machine-readable source of truth
|-- LEARNING.md           concise learner-facing projection
`-- artifacts/            optional work used as evidence
```

The route remains learner-controlled. Goal changes, required-node changes, target mastery changes, and changes to the completion contract require fresh approval. Small teaching adjustments can happen automatically when evidence supports them.

## What “effect” means here

Philomatheia is designed to produce observable operational effects:

- a new session can resume the same pending question without reconstructing chat history;
- a correct answer with heavy hints cannot establish independent mastery;
- prerequisite gates cannot be skipped by a high goal weight;
- later failures can lower current mastery while preserving historical evidence;
- completion requires both the required goal subgraph and an independent integrative task;
- source conflicts and unknowns remain visible.

The repository contains deterministic checks for these state invariants and reproducible behavioral evaluation guidance. It does **not** claim that using the skill guarantees higher grades, faster learning, professional competence, or better long-term retention. See [EVALUATION.md](EVALUATION.md) for current evidence and a longitudinal validation protocol.

## Requirements

- Any agent harness that loads Agent Skills from a directory, such as Codex or Claude Code
- Python 3.10 or newer for project initialization and state validation
- No third-party Python packages for the core scripts
- PowerShell 7 for the Windows installer, or a POSIX shell on macOS/Linux
- Node.js 18 or newer only if you install with `npx`

External research tools may still be needed when a learning project depends on current or specialized sources.

## Validate locally

```sh
python scripts/check_package.py
python -m unittest discover -s tests -v
python -m py_compile scripts/init_project.py scripts/validate_state.py scripts/check_package.py
```

GitHub Actions also exercises the package on Windows, macOS, and Linux.

## Repository map

| Path | Purpose |
|---|---|
| `SKILL.md` | Trigger boundary and core learning workflow |
| `references/` | Knowledge-map, teaching, evidence, state, source, and domain rules |
| `scripts/init_project.py` | Creates isolated project state without overwriting existing state |
| `scripts/validate_state.py` | Checks machine-verifiable learning-state invariants |
| `assets/` | Initial JSON and learner-facing Markdown templates |
| `agents/openai.yaml` | Optional display metadata for harnesses that read it |
| `EVALUATION.md` | Evidence status, behavioral scenarios, and outcome-testing method |

## Inspiration and license

Philomatheia was inspired by [`ai-engineering-from-scratch`](https://github.com/rohitg00/ai-engineering-from-scratch) and [ChongWen's notes on Skill design](https://www.chongwenz.cn/tech/AI/ai-skill-01/). It generalizes the idea into a user-defined learning workflow and does not bundle the original course lessons or quizzes.

Released under the [MIT License](LICENSE). Contributions are accepted under the same license.
