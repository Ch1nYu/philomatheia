# Mastery, evidence, and review

Use this reference before changing mastery, confidence, review timing, or pass-gate status.

## Mastery ladder

| Level | Observable claim |
|---|---|
| `0` | No relevant evidence yet |
| `1` | Recognizes or recalls the idea and places it on the map |
| `2` | Explains it in their own words and distinguishes related ideas |
| `3` | Applies, analyzes, or produces with structured support |
| `4` | Completes a representative task without material hints |
| `5` | Transfers, debugs, compares, integrates, or teaches it accurately |

Store target level per node. Supporting knowledge often stops at level 2; a useful skill usually needs level 4; central goal nodes may require level 5.

## Evidence quality

Strong evidence is observable, attributable to the learner, matched to the claimed level, and recent enough for the decision.

Useful evidence kinds include:

- `recall`
- `explanation`
- `comparison`
- `prediction`
- `guided_practice`
- `independent_practice`
- `artifact`
- `debugging`
- `teach_back`
- `transfer`
- `delayed_review`

Record result, demonstrated level, independence, hints used, artifact verification, source links, and error patterns. Do not infer ability from passive exposure or an agent-executed demonstration.

## Advancement

Raise current level only when evidence directly demonstrates it. Levels 4 and 5 require a passing independent attempt with zero material hints. Prefer two evidence shapes for important nodes, such as explanation plus practice or practice plus delayed review.

Do not average away a prerequisite failure. Do not raise multiple levels because of one unusually easy task. When evidence is borderline, preserve the level and update confidence or the next assessment.

## Regression

Keep `highest_level` and all historical evidence. Lower confidence, return a node to review, or lower `current_level` to the highest level still supported when multiple recent signals agree, a critical misconception appears, or delayed evidence shows the claimed ability is unavailable.

One careless error should usually update an error pattern, not rebuild the route. Change one instructional axis at a time and collect new evidence.

## Review selection

At session start, select at most one due review with the highest combination of:

- relevance to the active goal;
- prerequisite centrality;
- weak or old evidence;
- recurring error pattern;
- value for integrating current frontier nodes.

Use a short unprompted recall or representative micro-task. Success refreshes evidence and schedules a later review. Failure returns the node to the frontier or triggers a small prerequisite repair.

Schedule from observed retention rather than a universal calendar. Start with a near review when evidence is new or heavily prompted; expand the interval after independent delayed success; shorten it after partial recall, repeated errors, or high hint use. Record the reason with the date.

## Confidence

Confidence is a bounded decision aid from `0.0` to `1.0`, not a probability that the learner truly knows something. Increase it for independent, varied, verified, and delayed evidence. Reduce it for heavy hints, repeated error patterns, narrow task coverage, conflicting evidence, or long gaps.

Expose supporting evidence near any confidence value so the number cannot masquerade as certainty.
