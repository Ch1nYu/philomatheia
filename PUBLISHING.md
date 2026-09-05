# Publishing checklist

Publishing changes external state. Run these steps only after the repository owner has reviewed the files and authorized making the project public.

## Pre-publication gate

Complete every item before the repository becomes public. Each one is verifiable.

- [ ] Working tree is clean and `main` is level with `origin/main`.
- [ ] Every commit author is the GitHub noreply address, not a private email: `git log --format='%an <%ae>' | sort -u`.
- [ ] The local gate is green: package check, unit tests, compile check, release build.
- [ ] The latest `Validate` run on `main` is green on all three operating systems.
- [ ] No dependency or workflow update pull request is left open.
- [ ] No file contains private learner state, credentials, or unredacted transcripts.
- [ ] Effect claims in both READMEs still match [EVALUATION.md](EVALUATION.md).

## Repository settings

Apply these before flipping visibility, because the public landing page and the issue templates depend on them.

```powershell
gh repo edit Ch1nYu/philomatheia `
  --description "Persistent, evidence-based learning Skill with goal-specific knowledge maps and exact cross-session checkpoints." `
  --add-topic agent-skills --add-topic adaptive-learning --add-topic codex `
  --add-topic education --add-topic knowledge-graph --add-topic mastery-learning --add-topic python `
  --enable-discussions
```

Discussions is not optional: `.github/ISSUE_TEMPLATE/config.yml` sends users to `/discussions`, and that link is dead while the feature is off.

Then enable private vulnerability reporting, which [SECURITY.md](SECURITY.md) promises as the reporting channel:

```powershell
gh api -X PUT repos/Ch1nYu/philomatheia/private-vulnerability-reporting
```

Finally require the `Validate` workflow on `main`. Branch protection on a public repository is available on the free plan; configure it in repository settings under Rules, requiring the `Validate` status checks and a pull request before merge.

## First publication

The repository already exists privately, so publication is a visibility change rather than a fresh push. Confirm state first:

```powershell
gh auth status
git status
git log -1 --oneline
gh repo view Ch1nYu/philomatheia --json visibility,description,repositoryTopics
```

Then, only with explicit publication approval from the owner:

```powershell
gh repo edit Ch1nYu/philomatheia --visibility public --accept-visibility-change-consequences
```

Making a repository public is effectively irreversible for anything already pushed: forks, caches, and archives can retain the history even if visibility is reverted. Review the full commit history, not just the working tree, before running it.

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
