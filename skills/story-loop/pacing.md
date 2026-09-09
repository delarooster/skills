# Pacing

`/story-loop` runs **one iteration per invocation.** Repetition belongs to the
host.

| Host | Invocation |
|---|---|
| Claude Code | `/loop 20m /story-loop` |
| OpenCode | `/loop 20m /story-loop` (requires the loop plugin) |
| Codex | `while :; do codex exec "/story-loop"; sleep 1200; done` |

Two of the three get repetition for free. One iteration per invocation is also
what makes cold-start resume testable rather than aspirational: if an iteration is
the unit, then resuming is just the next invocation.

## The limit worth stating

A host loop wakes the **same** session with its context intact. It does not reset
anything and it does not compact anything. The context budget in
[orchestrator.md](orchestrator.md) is delivered entirely by the read-nothing
discipline, not by the loop mechanism. Anyone assuming the loop clears context
between stories will blow the window at roughly the same point as running without
it.
