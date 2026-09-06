# Publishing checklist

Publishing changes external state. Run these steps only after the repository owner has reviewed the files and authorized making the project public.

## Current state

The repository is public and `v0.1.0` is tagged on `origin`. The GitHub steps below are done; they stay here as the record of what was applied and as the checklist for every release after this one.

Outstanding:

- `0.2.0` is prepared in `VERSION`, `package.json`, `CHANGELOG.md`, and `CITATION.cff`, but not tagged or released.
- The npm package has never been published — see [npm publication](#npm-publication).

A public tag is never moved. Releasing anything newer than `v0.1.0` means bumping first, with those four files moving together and the tag equal to `v$(cat VERSION)`.

## Pre-publication gate

Applied before the repository became public. Re-run the same items before each release; each one is verifiable.

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

## First publication — done

This step has been carried out; the repository is public. It is kept as the record of how it was done.

The repository already existed privately, so publication was a visibility change rather than a fresh push. Confirm state first:

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

## Settings that require a public repository

These two cannot be applied earlier. GitHub answers the vulnerability-reporting endpoint with `404` while the repository is private, and free-plan branch protection only applies to public repositories.

Enable private vulnerability reporting, which [SECURITY.md](SECURITY.md) promises as the reporting channel:

```powershell
gh api -X PUT repos/Ch1nYu/philomatheia/private-vulnerability-reporting
```

Then require the `Validate` workflow on `main`. Configure it in repository settings under Rules, requiring the `Validate` status checks and a pull request before merge.

## Cutting a release — `v0.1.0` done

Run the full local gate:

```powershell
python scripts/check_package.py
python -m unittest discover -s tests -v
python scripts/build_release.py
```

Then create and push a version tag that exactly matches `VERSION`. A tag that already exists on `origin` is never moved; bump the version instead.

```powershell
$version = Get-Content VERSION
git tag -a "v$version" -m "Philomatheia v$version"
git push origin "v$version"
```

The `Release` workflow verifies the tag, rebuilds the archive, and creates the GitHub Release. Review the generated notes and release asset after the workflow completes.

## npm publication

`npx philomatheia` only works once the package is on the npm registry. The repository is already public, so this no longer changes what is visible; what it does change is permanent.

Never publish a version number that a public GitHub release already used for different code. `v0.1.0` is tagged and public, so the first npm publish must carry a bumped version.

Publishing to npm is close to irreversible. A version number can never be reused, and unpublishing is only permitted within 72 hours and only when nothing depends on the package; after that the remedy is `npm deprecate`, which leaves the code in place.

The npm account email is public. It appears in the registry metadata for every package the account maintains:

```sh
curl -s https://registry.npmjs.org/philomatheia | jq .maintainers
```

Use an address you are willing to publish, and one you will still control for account recovery years from now.

Before the first publish:

- [ ] The name is still free: `npm view philomatheia` answers `404`.
- [ ] `npm whoami` shows the intended account, and 2FA is enabled on it.
- [ ] `package.json` version equals `VERSION`, and `python scripts/check_package.py` is green.
- [ ] `npm pack --dry-run` lists the runtime, both installers, and `bin/philomatheia.js`, and no tests, workflows, or package tooling.
- [ ] The packed tarball installs: `npm pack`, then `npx --yes ./philomatheia-<version>.tgz --list` from another directory.

Then, with explicit approval from the owner:

```sh
npm publish
```

Verify afterwards from a directory that is not the clone:

```sh
npx philomatheia@<version> --list
```

## Future releases

1. Update `VERSION`, `package.json`, `CHANGELOG.md`, both READMEs when status or claims changed, and `CITATION.cff`.
2. Run the package checker, unit tests, installer smoke tests, and relevant behavioral forward tests.
3. Commit the release change.
4. Create and push the matching annotated tag.
5. Verify the GitHub Actions run and downloadable archive.
6. Publish the npm package with `npm publish`, then confirm with `npx philomatheia@<version> --list`.

Do not publish a release when learning-effect claims exceed [EVALUATION.md](EVALUATION.md), source attribution is incomplete, or cross-platform validation is red.
