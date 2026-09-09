---
name: story-loop
description: Run one queue-driven implementation iteration -- pick the next eligible story, hand it to a fresh subagent to implement and open a stacked pull request, dispatch a verifier, and log the result. Use when asked to "run the story loop", "work the backlog", "drain the story queue", "implement the next story", or invoke `/story-loop`; wrap it in the host's loop mechanism to run continuously.
compatibility: Requires git and a repo whose stories follow the plan-project folder state machine. Pull request creation additionally requires an authenticated forge CLI; without one, set forge to none and the loop chains branches only.
---

# Story Loop

Drain a story queue one item at a time, spending a fresh subagent context per
story so the orchestrator's own context stays flat. One iteration per invocation;
repetition belongs to the host. See [pacing.md](pacing.md).

## Precedence

This skill narrows two workspace rules, for the duration of one iteration and no
further. Both narrowings are stated here so no agent has to guess which rule wins.

| Rule | Narrowed to |
|---|---|
| `INSTRUCTIONS.md` git lockdown: every git write needs an explicit user command | Invoking `/story-loop` **is** that command, scoped to the grant below and to queued stories only |
| `commands/git.md`: invoking `/git` is not authorization to act on judge findings | Bounded remediation is authorized **below the adapter's escalation threshold only**: blocking findings only, at most 2 rounds, fresh verifier context every round. At or above it the loop stops and a human decides |

Outside them both rules apply unchanged, and neither transfers to another command,
repository, or session. If unsure whether an action is inside a narrowing, it is not.

## Authorization

**Invoking `/story-loop` authorizes, for queued stories only:** branch creation,
commits, pushes to those branches, pull request creation against the declared
base, and story file moves between state folders.

**It never authorizes:** merge, force push, rebase, reset, amend, tag operations,
branch deletion, any push to the base branch or to `main`/`master`/`develop`, git
config changes, or hook bypass. A subagent that believes it needs one of these
must return `blocked` with the reason instead.

## The orchestrator reads nothing

You are the orchestrator. You **must not** read source files, diffs, verdict
bodies, test output or CI logs, and you **must not** implement, commit, push or
edit story files yourself. Derive every decision from story headers and the log
using `scripts/loop-state.sh`. Full contract and budget:
[orchestrator.md](orchestrator.md). That script has its own tests:
`scripts/selftest.sh` and `scripts/e2e-chain.sh`, both safe to run anywhere.

## One iteration

Paths are relative to the consumer repo. Set `LS` to this skill's
`scripts/loop-state.sh` once and reuse it; the deployed skill directory differs per
host, so resolve it rather than assume it.

1. **Load the adapter.** `tasks/story-loop.md` holds queue root, log path, base
   branch, stack mode, depth cap, forge and verifier. Missing? Probe and write it:
   [adapter.md](adapter.md).

2. **Select.** `"$LS" eligible <queue-root> <log>` prints
   `id<TAB>deps<TAB>effort<TAB>path`, or nothing. Empty does not mean drained, so
   run `"$LS" stalled <queue-root> <log>` and log what it names before concluding
   otherwise: [orchestrator.md](orchestrator.md).

3. **Compute the parent.** `"$LS" parent <log> <base> <mode> <deps>`. This is the
   step that makes pull requests stack. Never let the implementer choose its own
   base. Read [chain.md](chain.md) before changing anything here.

4. **Spawn the implementer**, clean context and isolated tree, using the fixed
   template in [implementer-brief.md](implementer-brief.md). Host specifics:
   [runner-claude.md](runner-claude.md), [runner-codex.md](runner-codex.md),
   [runner-opencode.md](runner-opencode.md).

5. **Check the return.** `"$LS" check-base <parent> <returned-BASE>`. Non-zero is
   `blocked :: unstacked`, not a warning: [chain.md](chain.md).

6. **Verify**, if the adapter names a verifier. Wait for CI, dispatch by PR number
   with a fresh context, then route on the returned escalation score: at or above
   the adapter's threshold stop for a human, below it relay only blocking findings
   to the same warm implementer. [orchestrator.md](orchestrator.md).

7. **Move the story file** per the folder state machine, then
   `"$LS" append <log> <9 fields>` exactly one row.

8. **Stop or continue** against the conditions below.

## Stop conditions

- Queue empty, and nothing reported by `stalled`
- 2 consecutive stories return `blocked`
- A verifier returns a hold verdict twice on the same pull request
- **A verifier returns an escalation score at or above the adapter's threshold.**
  Stop before remediating, not after: the point of the threshold is that a human
  sees the finding before anything responds to it
- The authorization boundary above is hit
- User interrupt

Every stop writes a final log row naming which condition fired. If a story
completed in the same iteration, that is two rows: the story's, then the stop.

## Checklist

- [ ] Adapter loaded or written; nothing asked twice
- [ ] Parent computed by the orchestrator, never by the implementer
- [ ] Returned `BASE` checked against the supplied parent
- [ ] Exactly one log row appended, including for blocked and escalated stories
- [ ] Route taken from the escalation score alone, never from the summary
- [ ] Story bodies opened: zero. Verdict files opened: zero. Diffs read: zero
