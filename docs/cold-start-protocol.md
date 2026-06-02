# Cold-Start Protocol

Treat agent sessions like containers: cold start every command, read markdown as persistent state, do work, write state back, exit clean.

## Premise

Long-running sessions degrade -- attention loss past ~32k tokens, compaction hides dropped state, cross-session context evaporates. Markdown-on-disk is auditable, reliable, portable, and honest. A cold agent reading good notes outperforms a warm agent with degraded recall.

## The Three-File Contract

| File | Role | Analogy |
|------|------|---------|
| `CONTEXT.md` | Stable project substrate -- goals, constraints, terminology (rarely changes) | Container image |
| `tasks/CURRENT.md` | Volatile working set -- checklist, next action, open questions | Mounted volume |
| `tasks/DECISIONS.md` | Append-only log -- date, decision, rationale | Container logs |

## Read Order (every command, no exceptions)

1. `CONTEXT.md` -- restore project substrate
2. `tasks/DECISIONS.md` -- restore decision history
3. `tasks/CURRENT.md` -- restore active state

## Write Order (before exit)

1. `tasks/CURRENT.md` -- mark completions, set next action
2. `tasks/DECISIONS.md` -- append if a decision was made
3. `CONTEXT.md` -- update only if project scope shifted (rare, flag for user review)

## Rotation Rules

| File | Limit | Action |
|------|-------|--------|
| `tasks/CURRENT.md` | 100 lines | Rotate completed items to `tasks/archive/` |
| `tasks/DECISIONS.md` | 200 lines or 30 days | Move old entries to `tasks/DECISIONS-archive.md` |
| `CONTEXT.md` | No hard limit | Should describe project, not session |

## Anti-Patterns (what cold-start rejects)

- **Compaction** -- summarization is lossy; prefer explicit state in files.
- **Conversational memory** -- assume nothing survived from prior context.
- **Implicit state** -- if it matters, it is written to a file or it does not exist.
- **Long-lived sessions** -- every invocation is a cold start by definition.

## Cost

Every command pays a re-read tax. Re-reading 200 lines of structured markdown is cheap. Re-deriving lost context from a degraded session is expensive and lossy.

## Compatibility

This protocol is additive. Existing `/startup` + `tasks/CURRENT.md` flow continues unchanged. Cold-start commands (`/cs-*`) opt in explicitly. If the experiment fails, deleting the new files removes it cleanly.
