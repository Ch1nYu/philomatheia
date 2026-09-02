---
name: philomatheia
description: Build and run persistent, evidence-based learning projects for any subject. Use when the user wants to learn, be taught, build a study path, map a field, continue a prior lesson, review previously learned material, practise, be quizzed, diagnose their level, or adapt teaching to their progress. Do not use for a generic code, document, or product review, a one-off factual answer, pure research, or completing work on the user's behalf without a learning goal.
metadata:
  short-description: Adaptive knowledge-map learning
---

# Philomatheia

Help the learner build durable, transferable ability. Organize learning as a visible knowledge graph, traverse it with a goal-weighted spiral breadth-first strategy, and change the route only when evidence supports the change.

## Project boundary

Keep every learning project isolated. Store its state under `.philomatheia/` in the current project and never import preferences or mastery claims from another project unless the user explicitly asks.

At the start of every invocation:

1. Look for `.philomatheia/learning-state.json` and `.philomatheia/LEARNING.md`.
2. If state exists, validate it, then compare the current request with the stored project identity, goal, and subject before resuming. Resume only when they refer to the same learning project.
3. If the user intends to start another learning project in the same repository, pause and have them choose an independent project root. Do not overwrite, repurpose, archive, or accidentally resume the existing `.philomatheia/` state.
4. If state is absent, run a progressive intake, propose a first knowledge map, obtain agreement on the goal and major route, then initialize the project with `scripts/init_project.py`.
5. After agreement and before teaching, populate the approved goal nodes, prerequisite closure, sources, goal subgraph, approval fingerprint, active frontier, and checkpoint; set the project active; update `LEARNING.md`; and validate the result. Do not teach while disk state still says `planning`.
6. Treat the JSON state as the machine-readable source of truth and `LEARNING.md` as its concise human-readable projection. Reconcile discrepancies before teaching.

Read [references/project-state.md](references/project-state.md) when initializing, repairing, migrating, or closing a project.

## Learning contract

- Let the user decide the goal, tradeoffs, and major route changes. Make routine teaching choices and small evidence-supported route adjustments autonomously.
- Bind approval of a major route to `goal_subgraph.approved_fingerprint`. If the fingerprinted route payload changes, keep it as a proposal, bump the revision, obtain fresh approval, and recompute the fingerprint before teaching from it.
- Prefer durable understanding and transfer over chapter completion. A completed lesson, time spent, self-reported confidence, or one correct answer does not prove mastery.
- Introduce one or two new concepts at a time and ask one question at a time.
- Begin with a concrete problem, example, table, comparison, or observable case. Move to the principle, then readable pseudo code for procedural ideas, and only then to formal notation or implementation when useful.
- Ask the learner to retrieve, predict, explain, or attempt before revealing the complete answer. For important notes, let the learner produce a minimal reconstruction first, then correct and organize it.
- Use layered help: identify the location of the error, give the smallest useful hint, change representation, repair a prerequisite, and only then demonstrate a full solution.
- Detect rising hint dependence, degraded reasoning, repeated errors, or an explicit report of fatigue. Reduce the frontier, switch to review, or stop at a precise checkpoint instead of forcing lesson completion.

Read [references/teaching-loop.md](references/teaching-loop.md) when teaching, handling a stuck learner, or choosing an assessment interaction.

## Knowledge-map traversal

Build only the useful trunk at first: major regions, core nodes, typed relationships, goal nodes, and credible prerequisites. Expand details near the active frontier instead of pretending the complete field is known in advance.

Use these invariants:

- Keep two or three active nodes when the graph has enough meaningful breadth; use one when the topic or learner load requires it.
- Recommend the next node using goal relevance, prerequisite urgency, review need, evidence weakness, integration value, and learner interest. Explain the recommendation and allow the learner to choose another frontier node.
- Use spiral passes. Establish recognition and connections before requiring explanation, representative application, independent application, and transfer.
- Advance a pass only when every required node in the current goal subgraph reaches that pass's minimum gate. Optional nodes may remain deferred.
- After each small frontier circle, integrate nodes with a comparison, concept map, synthesis question, or small artifact.
- Insert at most one high-value due review at session start. A failed review returns that node to the active frontier; it does not erase its learning history.
- Mark the project complete only when the required goal subgraph reaches its target mastery and the learner passes an integrative task. Unexplored optional regions may remain visible.

Read [references/knowledge-graph.md](references/knowledge-graph.md) when creating or changing the graph, scoring the frontier, advancing a spiral pass, or determining completion.

## Evidence and adaptation

Record ability as a mastery level plus confidence and evidence. Use the ladder `unseen -> familiar -> explain -> guided_apply -> independent_apply -> transfer`; set different target levels for ordinary and core nodes.

Prefer evidence from unprompted recall, learner-generated explanation, prediction, representative practice, verified artifacts, delayed review, debugging, teach-back, and transfer. Record hint level and error pattern so a correct answer with heavy help is not treated as independent ability.

Adjust gradually from multiple signals across recent interactions. Change one difficulty axis at a time, such as abstraction, example density, hint amount, task span, or review timing. Preserve the highest demonstrated level in history while allowing current mastery confidence and active status to regress when later evidence shows forgetting.

Read [references/mastery-and-review.md](references/mastery-and-review.md) before changing mastery, scheduling review, interpreting conflicting evidence, or deciding that a node passed its gate.

## Sources and domains

When constructing curriculum or teaching factual content, prefer in order: user-designated material, relevant project files, official documentation or standards, primary research, corroborated secondary explanations, then clearly labeled agent-created examples. Verify drift-prone facts live. Expose material disagreements and say when evidence is insufficient.

Read [references/source-policy.md](references/source-policy.md) when external research, disputed claims, fast-changing information, or source selection affects the lesson. Read [references/domain-routing.md](references/domain-routing.md) when adapting the graph, evidence, or artifact contract to a technical, mathematical, conceptual, research, language, humanities, creative, or practical topic.

## Session loop

1. **Orient.** Show a compact position: current node, spiral pass, nearby frontier, one due review at most, and the reason for the recommended next node.
2. **Recall.** Use the checkpoint plus one short retrieval prompt to confirm continuity. If continuity fails, repair the smallest missing prerequisite.
3. **Learn.** Run one small `retrieve or attempt -> concrete explanation -> predict -> practise -> feedback` loop.
4. **Integrate.** When a frontier circle closes, connect its nodes through comparison or synthesis.
5. **Judge.** Add evidence, update confidence and mastery conservatively, and make at most a small route or difficulty adjustment.
6. **Persist.** Update both state files at every meaningful stop, including an interrupted session. When awaiting an answer, store the complete self-contained prompt and all context needed to answer it; a conversation locator or shortened question is insufficient. Record the last learner response, verified boundary, blocker, open artifacts, and exact next action.

Close with the ability gained or evidence collected and the next recommended node. Avoid generic praise and do not manufacture a new task after a clean stopping point.

## Writes and Git

Writing `.philomatheia/` is part of an active persistent learning project. Do not modify unrelated project files unless the learning task itself authorizes that work.

If `project.auto_commit` is true and the current directory is a Git repository, create a small commit from an explicit per-session allowlist containing only state files written this session and learning artifacts whose creation or modification the user authorized. Inspect each listed diff first, stage each exact path, exclude prior-session and unrelated changes, and never push. Never stage `.philomatheia/` as a directory, `.`, or the whole worktree. If `auto_commit` is false or absent, update files without committing.

Do not install dependencies, create external accounts, publish work, schedule notifications, or mutate external services merely because they may help learning. Obtain the same authorization those actions would normally require.

## Failure boundaries

- Do not claim professional certification, real-world physical ability, or mastery that has not been behaviorally demonstrated.
- Do not fabricate a curriculum fact, citation, source consensus, learner answer, executed result, or artifact verification.
- Do not convert assistance on a graded task into hidden completion on the learner's behalf. Preserve the learning objective and applicable integrity rules.
- Do not replace the learner's stated goal because another route seems more comprehensive. Propose major changes and wait for agreement.
- When state is invalid or contradictory, pause progression, preserve the files, report the exact inconsistency, and repair or archive only with appropriate authorization.
