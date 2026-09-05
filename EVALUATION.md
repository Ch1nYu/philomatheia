# Evaluation status

Philomatheia separates mechanical correctness, behavioral reliability, and real learning outcomes. Passing a schema check does not prove that a learner learned more.

## Current evidence

### Deterministic checks

The repository can currently verify:

- valid Skill frontmatter and required runtime files;
- project initialization without overwriting existing state;
- JSON state invariants, references, prerequisite gates, route fingerprints, evidence requirements, exact checkpoints, and completion gates;
- isolated installation on Windows and POSIX systems;
- update behavior that requires an explicit flag;
- Python syntax and unit tests on supported platforms.

These checks run in `.github/workflows/validate.yml`.

### Development forward tests

Two realistic, read-only behavioral smoke tests were run during initial development:

| Scenario | Observed behavior | Limit found |
|---|---|---|
| Learn recursive call/return order while easily fatigued | Created a compact graph, reduced the frontier to one with a recorded reason, saved a complete multiple-choice prediction question, and validated the checkpoint before waiting | The initializer only creates the planning skeleton; an agent must still populate and approve the active route before teaching |
| Learn restaurant Japanese with a severe peanut allergy | Kept language learning separate from safety claims, preserved the original ordering goal, and stopped at a direct production prompt | Text interaction cannot verify pronunciation or restaurant safety; those abilities must remain unverified without suitable evidence |

These are smoke tests of decision boundaries and persistence. They are not controlled learning studies.

## Claims not yet established

This project has not demonstrated that it:

- improves grades or test scores;
- reduces time needed to learn a subject;
- improves retention compared with another tutor;
- transfers equally well across all domains or models;
- establishes professional, physical, clinical, or safety-critical competence.

Public documentation and release notes should not imply these outcomes without new evidence.

## Reproduce behavioral smoke tests

Use an empty temporary project for each scenario.

1. Ask the agent to use the `philomatheia` skill with the scenario, then approve a bounded first route.
2. Stop immediately after the first learner-facing question.
3. Inspect `.philomatheia/learning-state.json` and run:

   ```sh
   python /path/to/philomatheia/scripts/validate_state.py .philomatheia/learning-state.json
   ```

4. Start a fresh session in the same project and ask the skill to resume.
5. Confirm that it repeats neither intake nor completed teaching, and presents the exact stored question or next action.
6. Record failures as state artifacts or redacted issue attachments. Do not rely only on a narrative summary.

## Suggested longitudinal validation

To test real learning effects, compare Philomatheia with a fixed-route tutor on the same subject and learner goal.

Measure at least:

- baseline performance before teaching;
- immediate independent performance with hint count;
- delayed unprompted recall after several days;
- transfer to a materially changed problem;
- route changes and the evidence that triggered them;
- resume fidelity after a new session or agent;
- time spent and learner-reported workload.

Predefine the tasks and scoring rubric. Keep graders blind to the learning condition when practical. Publish unsuccessful and ambiguous results alongside successful ones.

## Minimum release gate

A release is ready only when:

- package checks and unit tests pass;
- Windows and POSIX installer smoke tests pass;
- at least one technical and one nontechnical scenario preserve an exact checkpoint;
- known limitations remain visible in README and release notes;
- no claim of educational effectiveness exceeds the available evidence.
