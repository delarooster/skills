---
name: wrap
description: Session closing ritual — update item state in tasks/current.md before ending. Records state, never session narrative. Use when user says "wrap up", "close session", "end session", or at end of a work session.
compatibility: opencode
metadata:
  trigger: end-of-session
  writes-to: tasks/current.md
  writes: item state only, never session narrative
---

You are closing this session. Update the **state** in `tasks/current.md`. Follow these steps exactly.

## The contract for `tasks/current.md`

Read this before touching the file. It overrides any instinct to be thorough.

`current.md` carries **item state and nothing else**: what is queued, what is in flight,
what is blocked. It is not a session journal and it is not a place to be comprehensive.

- **Never append a `## Session <date>` section.** Session narrative belongs in
  `tasks/archive/`, written by `/clean`, not by this skill.
- **Never write a paragraph.** A queue entry is one line. If an item needs explaining, the
  explanation goes in its story file or its backlog item.
- **Update in place. Do not append narrative.** The steps below name the only things that
  may be added: a queue entry, a decision row, an open-question line. Everything else is
  narrative, and narrative is what makes this file grow session over session. If it got
  meaningfully longer and none of those three things was added, this skill did the wrong
  thing.

Leaving detail out does not lose it. It is already in the story file, the backlog item,
the PR body, or the decision register, which is where someone will actually look.

## Step 1 — Git state snapshot

Run:
```
git status
git log --oneline -5
```

Record the current state: branch, any uncommitted/staged files, last 5 commits.

## Step 2 — Mark completed tasks

In `tasks/current.md`, update any task checkboxes that were completed this session from `[ ]` to `[x]`. Do not mark tasks complete if they were only partially done.

## Step 3 — Append to the decision register

For every decision made this session that isn't already logged, append a row to the
decision register.

Find it before writing to it. Repositories in this workspace disagree on casing, so check
for `tasks/DECISIONS.md` and `tasks/decisions.md` both, and match whichever the project
already uses rather than creating a second one beside it. On a case-sensitive filesystem,
guessing creates a duplicate register that nothing reads. If the project has neither, use
the Decision Log table in `tasks/current.md`:

```
| [today's date] | [decision] | [rationale] |
```

Only log decisions that affect direction, architecture, or approach — not implementation details.

## Step 4 — Update next action

Add or replace a single `**Next:**` line wherever the file tracks what happens next: an
in-progress phase section if the project uses them, otherwise directly under the queue. A
queue-only `current.md` has no phase sections, so do not create one to hold this line:

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

Do not summarize the whole session. Do not rewrite sections that didn't change. Do not add
a section these steps do not name. If your edit made `tasks/current.md` meaningfully longer
without adding a queue entry, a decision row, or an open question, revert it and write
less.
