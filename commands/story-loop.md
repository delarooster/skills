---
description: Run one story-loop iteration — pick the next eligible story, hand it to a fresh subagent to implement and open a stacked pull request, verify, and log one row. Wrap in /loop to run continuously.
---

Load the `story-loop` skill and run **one** iteration against this repository.
Do not repeat; repetition belongs to the host.

The skill is the specification. Read it rather than acting from this file: the
authorization boundary, the precedence it claims over `INSTRUCTIONS.md` and
`commands/git.md`, and the orchestrator contract all live there.

## The two ways this goes wrong

**You start reading.** Every decision comes from `scripts/loop-state.sh`, not from
opening files. See the orchestrator contract.

**You let the implementer pick its base.** You compute the parent and hand it over,
then check what comes back. See the chain rules.

## Report

One log row, then two lines to the user: the story and its outcome, and the next
eligible story. If the queue drained or a stop condition fired, say which one.
