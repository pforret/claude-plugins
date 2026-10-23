# Item template (used by /fodo:add)

Write `docs/todo/<yyyy-mm-dd>.<type>.<slug>.md` (today's date, ISO) with this content:

```markdown
---
title: <short imperative title>
type: bug | change | feature
size: small | medium | large
status: planned
created: <yyyy-mm-dd>
files:
  - path/to/file.ext        # one per line; "(unknown)" if not yet determinable
---

# <title>

## Request
<the user's text, verbatim>

## Analysis
<why it is a bug/change/feature, what part of the system is involved, any risks or open questions>

## Impacted files
<bullet list with a one-line reason each>

## Plan
<numbered steps to implement>

## Acceptance criteria
<bullet list — how we will know it's done>
```
