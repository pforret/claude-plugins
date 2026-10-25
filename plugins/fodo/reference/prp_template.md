<!--
PRP (Product Requirements Prompt) sections appended to a todo item by "/fodo:plan <n>".
Principles: describe the task, the guardrails and the exit criteria; do not prescribe the steps.
Every line is read by the implementing agent on every run, so only write what it cannot infer from
the repo: decisions, repo knowledge, gotchas, and how to prove it is done. Context is king;
validation must be executable; use the codebase's own keywords and patterns; follow CLAUDE.md.
Replace every [bracket] and drop all <!-- --> comments; the dashboard renders them as literal text.
Keep it dense: the executing agent only has this file + the repo.
-->

## PRP

### Goal
[Specific end state. What exists / behaves differently when this is done.]

### Why
- [User or business value]
- [How it integrates with existing features]
- [Problem solved, for whom]

### Decisions taken
<!-- One line per option that was open during planning and how it was resolved (by the user or by default). -->
- [Question] → [Decision] ([who decided / rationale])

### Context the implementer MUST read
```yaml
- file: [path/to/example]
  why: [pattern to mirror, gotcha to avoid]
- url: [documentation URL]
  section: [specific section]
  critical: [the one insight that prevents a mistake]
```

### Known gotchas & guardrails
<!-- Repo-specific only. Things the agent would get wrong without being told: library quirks,
     conventions, what must not change (public signatures, file formats, behaviour other code relies on),
     config/routes/DB/docs that must be touched together. No generic coding advice. -->
- Mirror the existing patterns named under Context; do not introduce new ones for this item
- [CRITICAL: library X needs Y]
- [PRESERVE: ...]
- [Also update: ...]

### Approach
<!-- The intended shape in a few sentences: new vs modified files with their responsibility, and the
     pattern each mirrors. State an order only where it truly matters (migration before model, flag
     before rollout). No per-file pseudocode unless the detail is non-obvious. The agent decides the steps. -->
[approach]

### Validation loop (executable, in order)
<!-- This is the exit criteria. Every acceptance criterion maps to a command here, or to an explicit
     manual check with its expected result. The item is done when every level passes. -->
```bash
# Level 1 — syntax/style/types
[lint command]
# Level 2 — unit tests (list the test cases to add: happy path, validation error, failure mode)
[test command]
# Level 3 — integration / manual check
[command + expected output]
```

### Confidence
**[n]/10** that this can be implemented in one pass by an agent with only this file and the repo.
[One line on what would still make it fail, if anything.]
