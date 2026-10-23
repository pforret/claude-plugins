<!--
PRP (Product Requirements Prompt) sections appended to a todo item by "/fodo:plan <n>".
Principles: context is king; validation loops must be executable; use the codebase's own
keywords and patterns; start simple, validate, then enhance; follow CLAUDE.md.
Replace every [bracket]. Keep it dense: the executing agent only has this file + the repo.
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

### Current vs desired tree
```text
[only the directories/files that matter: existing ones to modify, new ones to create with
 one-line responsibility each]
```

### Known gotchas & library quirks
- [CRITICAL: library X needs Y]
- [This codebase convention: ...]

### Implementation blueprint
<!-- Ordered tasks. Each: file, action (CREATE/MODIFY), what to mirror, what to preserve. Pseudocode only where the detail is non-obvious. -->
```yaml
Task 1:
  MODIFY path/to/file:
    - FIND: "[anchor]"
    - CHANGE: [what]
    - PRESERVE: [signatures/behaviour]
Task 2:
  CREATE path/to/new_file:
    - MIRROR: path/to/similar_file
    - ...
```

### Integration points
```yaml
CONFIG:   [file + pattern]
ROUTES:   [file + pattern]
DB:       [migration / index]
DOCS:     [what to update]
```

### Validation loop (executable, in order)
```bash
# Level 1 — syntax/style/types
[lint command]
# Level 2 — unit tests (list the test cases to add: happy path, validation error, failure mode)
[test command]
# Level 3 — integration / manual check
[command + expected output]
```

### Anti-patterns
- Don't invent new patterns when existing ones work
- Don't skip validation because "it should work"
- Don't mock to make a test pass; fix the root cause
- Don't hardcode values that belong in config
- Don't catch all exceptions; be specific

### Confidence
**[n]/10** that this can be implemented in one pass by an agent with only this file and the repo.
[One line on what would still make it fail, if anything.]
