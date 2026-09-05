# Contributing

Contributions that improve reliability, portability, teaching decisions, source handling, or evaluation are welcome.

## Before opening a change

- Keep the Skill domain-general. Do not add a fixed curriculum to the core package.
- Preserve learner control over goals, major route changes, and completion contracts.
- Support mastery claims with observable evidence. Do not treat exposure, confidence, or one easy answer as mastery.
- Keep every learning project's state isolated under its own `.philomatheia/` directory.
- Preserve existing authorization boundaries. Learning intent does not authorize publishing, dependency installation, external writes, or work completed on the learner's behalf.

Open an issue before changing the schema version, mastery ladder, route fingerprint, or completion contract so migration and compatibility can be discussed.

## Development setup

Requirements: Python 3.10 or newer. The core scripts use only the standard library.

```sh
git clone https://github.com/Ch1nYu/philomatheia.git
cd philomatheia
python scripts/check_package.py
python -m unittest discover -s tests -v
python -m py_compile scripts/init_project.py scripts/validate_state.py scripts/check_package.py scripts/build_release.py
```

### Lint and type checking

This project intentionally ships no third-party lint or type-check configuration. The core scripts must run on a clean Python 3.10 interpreter with the standard library only, so a required linter or type checker would add a dependency that installers and hosts are not guaranteed to have.

The three commands above are the equivalent gate: `check_package.py` for public package structure and links, `unittest` for state tooling behavior, and `py_compile` for syntax. Match the style of the file you are editing instead of reformatting it with an external tool. Running a formatter or type checker locally is fine as long as the pull request adds no configuration file, no new dependency, and no unrelated reformatting.

## Pull requests

Include:

1. The learner-facing problem being solved.
2. The state or behavior invariant that changed.
3. Tests or a realistic forward-test scenario.
4. Any migration, privacy, source, or authorization impact.
5. Documentation updates for changed public behavior.

Behavioral tests should inspect the produced state and artifacts. Tests that only match wording or headings are insufficient.

Do not commit `.philomatheia/` learning projects, private learner data, copyrighted course material, credentials, or unredacted chat transcripts.

## Documentation and language

Keep `README.md` and `README.zh-TW.md` aligned for installation, behavior, effect claims, and limitations. Small wording improvements do not require a line-for-line translation.

## License

By contributing, you agree that your contribution is licensed under this repository's [MIT License](LICENSE). Confirm that any third-party material is compatible and documented in [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).
