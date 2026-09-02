# Publishing checklist

Publishing changes external state. Run these steps only after the repository owner has reviewed the files and authorized making the project public.

## Repository settings

Recommended GitHub description:

> Persistent, evidence-based learning Skill with goal-specific knowledge maps and exact cross-session checkpoints.

Recommended topics:

```text
agent-skills adaptive-learning codex education knowledge-graph mastery-learning python
```

Enable Discussions, private vulnerability reporting, and branch protection that requires the `Validate` workflow before merge.

## First publication

Confirm authentication and the local commit before creating the public repository:

```powershell
gh auth status
git status
git log -1 --oneline
gh repo create Ch1nYu/philomatheia --public --source . --remote origin --push
```

The last command creates a public GitHub repository and pushes code. It must not be run without explicit publication approval.

## First release

Run the full local gate:

```powershell
python scripts/check_package.py
python -m unittest discover -s tests -v
python scripts/build_release.py
```

Then create and push a version tag that exactly matches `VERSION`:

```powershell
git tag -a v0.1.0 -m "Philomatheia v0.1.0"
git push origin v0.1.0
```

The `Release` workflow verifies the tag, rebuilds the archive, and creates the GitHub Release. Review the generated notes and release asset after the workflow completes.

## Future releases

1. Update `VERSION`, `CHANGELOG.md`, both READMEs when status or claims changed, and `CITATION.cff`.
2. Run the package checker, unit tests, installer smoke tests, and relevant behavioral forward tests.
3. Commit the release change.
4. Create and push the matching annotated tag.
5. Verify the GitHub Actions run and downloadable archive.

Do not publish a release when learning-effect claims exceed [EVALUATION.md](EVALUATION.md), source attribution is incomplete, or cross-platform validation is red.
