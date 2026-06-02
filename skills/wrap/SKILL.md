---
name: wrap
description: Session closing ritual — persist in-session context to tasks/current.md before ending. Use when user says "wrap up", "close session", "end session", or at end of a work session.
compatibility: opencode
metadata:
  trigger: end-of-session
  writes-to: tasks/current.md
---

You are closing this session. Capture all in-session knowledge to `tasks/current.md` before the session ends. Follow these steps exactly.

## Step 1 — Git state snapshot

Run:
```
git status
git log --oneline -5
```

Record the current state: branch, any uncommitted/staged files, last 5 commits.

## Step 2 — Mark completed tasks

In `tasks/current.md`, update any task checkboxes that were completed this session from `[ ]` to `[x]`. Do not mark tasks complete if they were only partially done.

## Step 3 — Append to Decision Log

For every decision made this session that isn't already in the log, append a row to the Decision Log table in `tasks/current.md`:

```
| [today's date] | [decision] | [rationale] |
```

Only log decisions that affect direction, architecture, or approach — not implementation details.

## Step 4 — Update next action

Find the current in-progress phase section and add or replace a `**Next:**` line:

```
**Next:** [concrete action — specific enough that a cold session can start immediately]
```

One line only. Replace any existing Next entry.

## Step 5 — Surface open questions

If there are unresolved questions or blockers from this session, append them under a `## Open Questions` section (create it if it doesn't exist):

```
- [question or blocker] — context: [why it matters]
```

Remove any questions that were resolved this session.

## Step 6 — Confirm

Report back:
- Files modified
- Tasks marked complete
- Decisions logged
- Next action set
- Open questions updated

Do not summarize the whole session. Do not rewrite sections that didn't change. Append and update only.
