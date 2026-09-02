# Security policy

## Supported versions

Security fixes are applied to the latest tagged release and the default branch during the `0.x` series.

## Report a vulnerability

Use GitHub private vulnerability reporting or a private security advisory for this repository. Do not open a public issue containing exploit details, credentials, private learning state, or sensitive artifacts.

Include the affected version, operating system, reproduction steps, impact, and the smallest safe proof of concept. Remove tokens, personal data, and unrelated project files.

## Security boundaries

Philomatheia's bundled Python scripts use the standard library and operate on local project state. The installer copies a fixed runtime allowlist into the user's Agent Skills directory. The Skill may ask a host to use other tools while teaching, but those tools retain their normal permission and authorization requirements.

Learning-project state can contain personal goals, errors, and artifacts. Treat `.philomatheia/` as private by default and review it before committing or sharing.
