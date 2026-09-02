# Source policy

Use this reference when curriculum construction or teaching depends on external, disputed, specialized, or fast-changing information.

## Priority

Choose the strongest relevant source available:

1. material the learner explicitly selected;
2. authoritative files and runtime evidence in the current project;
3. official documentation, standards, or maintained primary specifications;
4. original research and primary historical material;
5. corroborated high-quality secondary explanations;
6. clearly labeled agent-created examples used only to explain verified principles.

A user-selected source controls lesson scope, but it does not turn a false claim into fact. Surface material errors respectfully and support the correction.

## Verification

- Verify facts that may have changed before teaching them as current.
- Prefer primary sources for technical behavior, laws, medical claims, financial claims, scientific results, and precise quotations.
- Distinguish a source's statement, the agent's inference, an analogy, and an illustrative example.
- When sources disagree, show the material disagreement and its consequence for the lesson.
- When evidence is insufficient, mark the node or claim unresolved instead of filling the gap with a plausible explanation.

## Provenance record

Record enough information to re-check important curriculum claims:

```json
{
  "id": "src-transformer-paper",
  "type": "primary_research",
  "title": "Attention Is All You Need",
  "locator": "https://arxiv.org/abs/1706.03762",
  "publisher_or_author": "Vaswani et al.",
  "accessed_at": "2026-09-01T00:00:00Z",
  "version": "arXiv v7",
  "supports": ["transformer-core-architecture"],
  "conflicts": [],
  "limits": "Does not establish current production best practice"
}
```

Do not store copied source text merely to make state self-contained. Keep concise claims and locators, subject to copyright and access constraints.

## Knowledge-map changes

Treat a prerequisite edge or curriculum claim as sourced content when it is domain-dependent. Record a rationale and source. If new evidence changes a major region or goal route, propose the change before rewriting the approved map.
