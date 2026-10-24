---
name: done
description: Finish a busy docs/todo/ item. Verify every acceptance criterion and validation command, append a Result section (verification, deviations, discoveries, changes) and archive it to docs/todo/done/. Use when asked to "mark todo done", "finish the current item" or "close B1".
argument-hint: "[Bn]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (item id; empty = the current item): $ARGUMENTS

## DONE

Empty id = current item (`fodo.sh path ""`). Otherwise `<id>` is normally a `Bn`.

1. Read the item fully (Request, Acceptance criteria, Plan/PRP, and any notes added during START).
2. **Verify it is actually done**: check every acceptance criterion (and, if there is a PRP, every
   validation command and success criterion) against the working tree: grep for the change, run the
   tests/linters named in the plan, look at `git status`/`git log`/`git diff`. Keep the exact
   commands and their outcome; they go into the file. If anything is unmet, say exactly what and
   stop. Do not write the Result section and do not move the file.
3. **Always append a `## Result` section** to the item file, with these four sub-sections (write
   "none" rather than omitting one):

```markdown
## Result

### Verification
<one bullet per acceptance criterion / validation gate: the command or check that was run and its
 outcome, e.g. "`composer test` → 42 passed", "grep confirms `oldName` no longer referenced">

### Deviations from the spec
<where the implementation differs from the Request, Plan or PRP, and why: scope dropped or added,
 a different approach, a decision taken that the plan left open. "none" if it matched exactly>

### Discoveries
<things learned during execution worth keeping: surprising behaviour, hidden coupling, bugs found
 elsewhere, tech debt noticed, follow-up work that should become its own todo item>

### Changes
<files touched (one line each), commits involved if any>
```

   Base this on what actually happened in the session and on the notes/checkmarks in the item's
   Plan or blueprint, not on what the plan intended. If a Discovery deserves follow-up, offer to
   create it with `/fodo:add` after the move; do not create it silently.
4. Move: `fodo.sh move-file <path> done` (sets `status: done`, `done_at`, clears the current item).
   Report the new path.
