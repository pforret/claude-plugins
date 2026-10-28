# Decision records (used by /fodo:decide and by the other skills when a decision is made)

Decisions are records, not items: they live in `docs/todo/decisions/`, are never moved, and are
written only through the helper (`fodo.sh decide`, `fodo.sh gotcha`), which also rebuilds
`decisions/index.md`. Edit the body of a decision file freely afterwards.

## Decision file

`fodo.sh decide "<title>" [--item <item file>] [--by <skill>]` writes
`docs/todo/decisions/<yyyy-mm-dd>.<slug>.md` (two filename segments, no type) and prints its path:

```markdown
---
title: <the decision, as one imperative or declarative sentence>
date: <yyyy-mm-dd>
status: accepted                     # or superseded (then add superseded_by: <decision filename>)
item: <item filename>                # the todo item it came from, when there is one
recorded_by: decide | plan | done | add | start | review
---

# <title>

## Context
<what made this decision necessary; the item, the constraint, the question that came up>

## Options considered
<one bullet per option, with its trade-off>

## Decision
<title>

## Consequences
<what becomes easier or harder; what to remember when touching this area>
```

The helper fills the frontmatter, the heading and `## Decision`; the skill that called it replaces
the three `<…>` placeholders with real prose from the conversation. Keep it short: a decision file
is read by the next agent that touches the area, not by a committee.

## Gotcha line

`fodo.sh gotcha "<text>"` appends one line to `docs/todo/decisions/gotchas.md` (created on first
use, never indexed) and prints the file path:

```markdown
- <yyyy-mm-dd> path/to/file: <one sentence>
- <yyyy-mm-dd> <one sentence without a file>
```

Start the text with `path/to/file:` (any path substring, no spaces, up to the first colon) when the
gotcha is about a file: the SessionStart hook prints such lines when that path appears in the
current diff. A gotcha is a fact that would surprise the next agent ("the `subscriptions` table is
append-only, take the highest version, not the latest `created_at`"), not a todo and not a decision.

## When a skill records a decision

| Skill | Trigger | Form | `--by` |
|-------|---------|------|--------|
| `/fodo:decide` | the user asks for it ("we decided", "record this decision", "note this gotcha") | decision or gotcha | `decide` |
| `/fodo:plan` | after the PRP is written, its `### Decisions taken` rows | one multi-select question, one decision per selected row, `--item` set | `plan` |
| `/fodo:done` | `### Deviations from the spec` is not "none" | one yes/no question, one decision per deviation bullet, `--item` set | `done` |
| `/fodo:done` | a Discovery that reads like a gotcha (surprising fact about a file or tool) | one multi-select question, gotcha lines with the path | `done` |
| `/fodo:add`, `/fodo:start` | the request text states a decision explicitly ("we decided to …", "use X instead of Y", "decision:") | decision, no question asked | `add` / `start` |
| `/fodo:review` | a reviewed decision is superseded or should become a rule or test | edits `status`/`superseded_by` with `fodo.sh set`, or queues `/fodo:add` | `review` |

Never ask more than one question per skill for recording. Never store a `D<n>` ID in a file: link
decisions to each other and to items by filename.
