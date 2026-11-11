# Runner: Claude Code

Verified against Claude Code 2.1.228.

## Spawn

The `Agent` tool. One story per agent, background so the completion notification
wakes the orchestrator rather than the orchestrator polling.

```
Agent(
  description: "implement <story-id>",
  subagent_type: <adapter Implementer agent>,
  run_in_background: true,
  isolation: "worktree",
  prompt: <the implementer brief>
)
```

Dispatch agents by name when they are installed: the adapter's `Implementer agent`
(default `story-implementer`) and its `Verifier`. Which agents a skills repo's
`setup.sh` copies into `~/.claude/agents/` varies by repo, so check rather than
assume. A repo agent of the same name in `.claude/agents/` takes precedence over the
user-level one, which is how a repo carries its own implementer rules. When the
named implementer is not installed, fall back to `general-purpose` with the full
brief. Each agent runs on the model its own definition sets; an adapter `Model
tiers` entry may override that, but never with a model name the host has not been
seen to route. At the start of an iteration that needs a verifier, check once that
it is installed and dispatchable. If it cannot be dispatched, stop with `judge
unavailable`: never use a full-history fork, a generic replacement or a failed
dispatch as a verdict.

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
heartbeat only (1800s).

Wait on CI the same way: one `Bash` call with `run_in_background: true` running the
forge's checks verb in watch mode under a `CI wait` timeout, then act on its exit notification. No `sleep`
loops and no repeated checks turns.

## Authorization

Where host or user rules put every git write behind an explicit user command, the
standing grant in [SKILL.md](SKILL.md) is what covers the
implementer's commits and pushes. It does not extend to anything on the forbidden
list, and a subagent that hits one returns `blocked`.
