# Changelog

All notable changes to this project will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- An npm entry point: `npx philomatheia` installs the skill without cloning the repository, on Node 18 or newer. The package carries the same runtime files and the same installers; `bin/philomatheia.js` only picks the platform's installer and translates the flags, so the selection prompt and detection logic stay single-sourced. The npx surface uses the POSIX flag names on every platform, including Windows.

### Changed

- Limited the `Validate` push trigger to `main` and added a concurrency group, so a change is validated once instead of twice and superseded runs are cancelled.
- Removed the dependency on any one host's built-in skill installer. Installation is `git clone` plus the bundled script on every platform.
- Both installers now ask which harnesses to install into, and install into none by default. The prompt lists every known harness with its status (`installed`, `detected, not installed`, `harness not found`) plus an entry for a directory of your own; pressing Enter cancels without touching anything. A destination that already holds an installation is replaced only after an explicit confirmation.
- Added `--list` / `-ListTargets` to print the harness status table without installing, and `--all` / `-All` to select every harness already present.
- A session that cannot prompt (a pipe, CI, or `PHILOMATHEIA_NON_INTERACTIVE=1`) no longer guesses a destination: it prints the status table and exits with code 2 unless `--dest-root`, `-DestinationRoot`, `--all`, or `-All` names the targets.
- `--dest-root` and `-DestinationRoot` accept several destinations and skip the prompt.
- Rewrote installation documentation and prompt examples to be host-neutral. Vendor-specific invocation syntax no longer appears in the READMEs, `INSTALL.md`, or `EVALUATION.md`.
- Broadened the independence statement to cover every agent-harness vendor.
- The release archive no longer carries `check_package.py` and `build_release.py`, matching what `INSTALL.md` promises and what both installers already enforce.
- Recorded in the publishing checklist that the repository is public and `v0.1.0` is tagged, so a later release requires a version bump rather than a moved tag.
- Updated GitHub Actions to `actions/checkout@v7` and `actions/setup-python@v7`.
- Documented the deliberate absence of third-party lint and type-check tooling in the agent handoff.
- Removed `CONTRIBUTING.md`; the inbound license term it carried is now one line in both READMEs.
- Excluded `PUBLISHING.md` from the release archive, since the checklist is for maintainers rather than users.
- Rewrote the publishing checklist as a verifiable pre-publication gate with explicit repository-settings commands, and corrected the first-publication step to a visibility change on the existing repository.

## [0.1.0] - 2026-09-02

### Added

- Domain-general, goal-weighted spiral knowledge-map learning workflow.
- Evidence ladder from recognition through independent transfer.
- Project-local JSON state, learner-facing Markdown projection, and exact checkpoint contract.
- Route approval fingerprints, prerequisite gates, review selection, source provenance, and completion invariants.
- Zero-dependency project initializer and state validator.
- Windows and POSIX installers with preview and explicit update modes.
- English and Traditional Chinese public documentation, evaluation protocol, security policy, acknowledgments, and MIT license.
- Cross-platform GitHub Actions validation, unit tests, versioned release archives, and SHA-256 checksums.

[Unreleased]: https://github.com/Ch1nYu/philomatheia/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ch1nYu/philomatheia/releases/tag/v0.1.0
