# Project state

Use this reference when creating, resuming, repairing, migrating, or closing a Philomatheia learning project.

## Files

Keep all persistent learning state inside the current project's `.philomatheia/` directory:

```text
.philomatheia/
|-- learning-state.json   Machine-readable source of truth
|-- LEARNING.md           Human-readable projection and learner notes
`-- artifacts/            Optional evidence produced for learning
```

Do not depend on a global learner profile. Record project-specific language, explanation preferences, pace, and artifact choices in the project state.

Initialize with:

```text
python <skill>/scripts/init_project.py --root <project> --title <title> --goal <goal> --domain <domain>
```

The initializer refuses to overwrite existing state. Preserve and inspect an existing project before resetting or archiving it.

Before resuming, compare the current request with `project.id`, the stored goal, and subject scope. If the user wants a different learning project in the same repository, require a separate project root and initialize there. Do not overwrite or reinterpret the existing `.philomatheia/` directory as the new project.

## JSON model

`learning-state.json` contains these top-level objects:

| Field | Purpose |
|---|---|
| `schema_version` | State format, initially `philomatheia.learning-state/0.1` |
| `project` | Identity, timestamps, status, domain, language, and `auto_commit` |
| `learner_contract` | Project-local teaching and interaction preferences |
| `goal` | Desired ability, target nodes, and integrative completion contract |
| `graph` | Knowledge nodes, typed edges, and map version |
| `goal_subgraph` | Required nodes, target mastery, goal weights, approved revision, and approval fingerprint |
| `planner` | Spiral pass, active frontier, reasons, and one inserted review at most |
| `sources` | Source provenance and the claims each source supports |
| `checkpoint` | Exact resumable session boundary |
| `session_log` | Compact history of completed or interrupted sessions |

### Node contract

Each graph node needs identity, source links, and a learning record:

```json
{
  "id": "stable-kebab-id",
  "title": "Human title",
  "kind": "concept",
  "source_ids": ["src-official-docs"],
  "learning": {
    "current_level": 0,
    "highest_level": 0,
    "confidence": 0.0,
    "evidence": [],
    "error_patterns": [],
    "last_seen": null,
    "next_review": null
  }
}
```

Allowed `kind` values are `concept`, `skill`, `procedure`, `fact`, `strategy`, and `integration`. Mastery levels are integers `0..5` as defined in `mastery-and-review.md`.

Represent relationships once in `graph.edges`:

```json
{
  "from": "vectors",
  "to": "dot-product",
  "type": "prerequisite",
  "weight": 1.0,
  "rationale": "Dot products operate on vectors.",
  "source_ids": ["src-course-text"]
}
```

Use `prerequisite`, `part_of`, `contrasts`, `applies_to`, or `analogous_to`. Keep prerequisite edges acyclic. A graph may contain cycles through the other relationship types.

### Route approval contract

`goal_subgraph.approved_fingerprint` binds user approval to the exact major route. It is `null` while planning and must be `sha256:<64 lowercase hex>` while the project is active or complete.

Hash canonical UTF-8 JSON containing only:

- `revision`;
- sorted `goal.target_node_ids`;
- `goal_subgraph.nodes`, sorted by `node_id`, with only `node_id`, `required`, `target_level`, and `goal_weight`;
- the complete `goal.completion_contract` except runtime fields `status` and `evidence_id`.

Serialize with sorted object keys and compact separators before SHA-256 hashing. Approval applies to this fingerprint, not merely to a revision number. If any canonical field changes, retain the change as a proposal, increment the revision, obtain fresh user approval, and store the new fingerprint before activating the route. A fingerprint mismatch is invalid state and must pause teaching.

### Evidence contract

Append evidence rather than replacing it:

```json
{
  "id": "ev-20260901-001",
  "at": "2026-09-01T10:00:00+08:00",
  "session_id": "session-20260901-01",
  "kind": "independent_practice",
  "result": "pass",
  "demonstrated_level": 4,
  "independent": true,
  "hints_used": 0,
  "artifact": ".philomatheia/artifacts/example.py",
  "artifact_verified": true,
  "notes": "Handled a representative case and explained the result.",
  "source_ids": ["src-official-docs"]
}
```

Every evidence record must contain every field shown above. Use `null` when there is no artifact and `false` when no artifact was verified; do not omit the fields. Level 5 needs passing evidence whose `kind` demonstrates transfer, debugging, comparison, or teach-back. Completion evidence needs a passing integration or capstone `kind` and must satisfy the completion contract. Keep paths project-relative. Record observable performance, not inferred personality.

## Checkpoint contract

Update the checkpoint at every meaningful stop, including interruption. Exact resume requires the following stored fields and linked state:

- `project.id`, `goal.statement`, and `checkpoint.map_version` through the current state;
- `checkpoint.status`, `checkpoint.session_id`, `checkpoint.saved_at`, `checkpoint.active_node_id`, and `checkpoint.phase`;
- the complete `planner.frontier`, including reasons, plus `planner.inserted_review_node_id`;
- `checkpoint.last_completed_action` and `checkpoint.resume_summary`;
- `checkpoint.pending_question` when awaiting an answer;
- `checkpoint.verified` and `checkpoint.blockers`;
- `checkpoint.new_evidence_ids`, with artifact verification recorded in the referenced evidence, and `checkpoint.open_artifacts`;
- `checkpoint.mastery_changes`, including reasons;
- `checkpoint.load_response` and `checkpoint.pending_major_route_proposal`;
- one exact `checkpoint.next_action`.

When awaiting an answer, `pending_question` must contain the complete original prompt, including the scenario, examples, choices, and response contract needed without the old conversation. Alternatively it may be a safe project-relative locator under `.philomatheia/artifacts/` whose local file contains that complete prompt. A chat, conversation, thread, URL, message ID, or other ephemeral locator is not sufficient.

Do not write `complete` when the learner merely watched a demonstration. Keep the continuation point narrow enough that another agent can resume without reconstructing the lesson.

If a prompt is too large for a concise checkpoint, store it in `.philomatheia/artifacts/` and put the project-relative artifact path in `pending_question`. Do not use `conversation:` or another ephemeral locator as the only copy.

## Human-readable projection

Keep `LEARNING.md` concise and regenerate factual status from JSON:

1. Mission and completion contract
2. Compact knowledge-map location
3. Active frontier with reasons
4. Mastery evidence summary
5. Review queue
6. Current checkpoint
7. Learner reconstruction and corrected notes
8. Recent session log

The learner's notes may use their own wording. They do not silently override machine state. If the files disagree, preserve both and reconcile from concrete evidence.

## Commits

When `project.auto_commit` is true:

1. Record an explicit per-session allowlist of state files written this session and learning artifacts whose creation or modification the user authorized.
2. Inspect repository status and every allowlisted diff.
3. Stage each exact allowlisted path. Never stage `.philomatheia/` as a directory, `.`, `-A`, prior-session artifacts, or unrelated changes.
4. Validate state before committing.
5. Never push.

Use a concise message such as `chore(learning): checkpoint <topic>`.
