# Runner: Claude Code

Verified against Claude Code 2.1.228.

## Spawn

The `Agent` tool. One story per agent, background so the completion notification
wakes the orchestrator rather than the orchestrator polling.

```
Agent(
  description: "implement <story-id>",
  subagent_type: "general-purpose",
  run_in_background: true,
  isolation: "worktree",
  prompt: <the implementer brief>
)
```

## Isolate

`isolation: "worktree"` is native: the agent gets its own git worktree, and it is
auto-removed if unchanged. Use it. Without it the implementer and the verifier
contend for the shared checkout, and the verifier may build a tree that is not the
pull request head.

The worktree is created from the current checkout, so the brief must still say
which parent to branch from. Isolation is not the same as the right base.
Keep the implementer and its worktree available through verification, remediation,
and the final story-state commit.

## Resume warm for remediation

`SendMessage` to the agent's id or name. Its context is warm, so a bounded fix
costs a fraction of a fresh spawn. A new `Agent` call would start cold and is the
wrong tool here.

Do not re-spawn the verifier this way: it must be cold every round. Use a fresh
`Agent` call for each verify pass, including remediation rounds.

## Structured return

Prompt-enforced. State the return template in the brief and reject a
non-conforming return once. There is no schema enforcement on the `Agent` tool
itself in this path.

## Pace

`/loop 20m /story-loop` for interval mode, or `/loop /story-loop` to let the model
self-pace. The loop wakes the same session with context intact; see
[pacing.md](pacing.md).

Do not schedule short wakeups to poll for the implementer. A backgrounded agent
re-invokes the orchestrator on completion, so any wakeup should be a long fallback
heartbeat only.

## Authorization

Global rules in this workspace put every git write behind an explicit user
command. The standing grant in [SKILL.md](SKILL.md) is what covers the
implementer's commits and pushes. It does not extend to anything on the forbidden
list, and a subagent that hits one returns `blocked`.
