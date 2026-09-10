---
description: Close out a session — archive completed work from scratchpad and current.md, sweep finished review verdicts, and reset for the next session
---

Archive the work from scratchpad.md and current.md and clean the files for next
session.

## Safety first

**Check `git status` before moving anything.** Untracked files exist only in this
working tree; a move you get wrong is unrecoverable. Never delete under this
command — only move, and only into `tasks/archive/`.

**Verify facts against the repo, not against the prose.** `CURRENT.md` is written
by hand and drifts. Check `git log`, `gh pr list`, and the branch you are actually
standing on before writing any of it into the archive. If the working tree sits on
a merged or stale branch, say so rather than recording what it shows.

## What to archive

**`scratchpad.md` and `CURRENT.md`** — the named targets. Write one dated session
record into `tasks/archive/`, then reset both files. Carry forward anything still
live: standing notes, open decisions, unfinished work.

**`tasks/reviews/pr-<N>.md`, when PR N is merged or closed.** A verdict on a
settled PR is history; a verdict on an open PR is live. Check state with
`gh pr view <N> --json state` and move only the settled ones, into
`tasks/archive/reviews/`.

This is now a safety net rather than the main path. `commands/git.md` closes each
cycle out on its own branch, so a verdict reaching this command usually means its
pull request was abandoned, or landed without a closeout. Both are worth naming in
the report rather than sweeping silently -- a verdict that keeps needing this
command is a cycle that keeps ending untidily.

Keep `tasks/reviews/README.md` where it is. Its calibration table only has value
as it accumulates across sessions, so it never archives.

## What NOT to archive

**`tasks/backlog/`. Ever.** It is the live forward queue, not session state.
Archiving it deletes the work list. Struck-through items stay in place — the
strikethrough plus its PR reference *is* the record.

Do check it for drift, which is the failure this rule exists to prevent: if items
show as open locally but merged on the default branch, the checkout is stale.
Report that; do not "fix" it by editing, or the same edit lands twice and
conflicts on the next pull.

**`tasks/stories/`. Ever.** The state folders under it *are* the dependency
ledger that `/story-loop` reads. A completed story belongs in
`tasks/stories/6_completed/`, never in `tasks/archive/`. Move one out of the queue
root and every story declaring it as a dependency is reported
`dependency unsatisfiable` forever, while the queue reports itself drained.

**Anything under `.claude/`.** Agent definitions and configuration are tooling,
not session output.

## Finish

Report what moved, what was reset, and what was deliberately left alone. Name
anything still uncommitted, so it is a decision rather than an oversight.
