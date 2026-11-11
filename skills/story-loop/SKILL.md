---
name: story-loop
description: Run one queue-driven implementation iteration -- pick the next eligible story, hand it to a fresh subagent to implement and open a stacked pull request, dispatch a verifier, and log the result. Use when asked to "run the story loop", "work the backlog", "drain the story queue", "implement the next story", or invoke `/story-loop`; wrap it in the host's loop mechanism to run continuously.
compatibility: Requires git and a repo whose stories follow the plan-project folder state machine. Pull request creation additionally requires an authenticated forge CLI (`gh` or `az`); without one, set forge to none and the loop chains branches only. GitHub native stacking optionally uses the `gh stack` extension (`github/gh-stack`); without it, or with `Native stacks: off`, pull requests stack on git branches alone.
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
| The host's git lockdown: every git write needs an explicit user command | Invoking `/story-loop` **is** that command, scoped to the grant below and to queued stories only. It covers a merge only when the adapter's `Merge policy` is `clean-verdict`, a human having set that field |
| A judge's verdict is not authorization to act on its findings | Bounded remediation is authorized **below the adapter's escalation threshold only**: blocking findings, plus the SHOULD FIX findings of a MERGE AFTER FIXES only when the adapter sets `Remediate should-fix: on`, at most 2 rounds, fresh verifier context every round. At or above the threshold the loop stops and a human decides |

Outside them both rules apply unchanged, and neither transfers to another command,
repository, or session. If unsure whether an action is inside a narrowing, it is not.

## Authorization

**Invoking `/story-loop` authorizes, for queued stories only:** branch creation,
commits, pushes to those branches, pull request creation against the declared
base, story file moves between state folders on the story branch, native stack
linking of those pull requests (`gh stack link`, [native-stacks.md](native-stacks.md)),
writing a missing adapter on its own branch with a tasks-only pull request for it
(with `Forge: none`, push that branch and stop for the operator), dispatching the
adapter's `Narrowed e2e` workflow or pipeline (`gh workflow run`, `az pipelines run`)
on the story branch only, once per story as [implementer-brief.md](implementer-brief.md)
directs, and the
[closeout commit](orchestrator.md#closeout) on a clean verdict -- `tasks/` only, on
the branch, unprompted, by whoever the adapter's `Closeout by` names. An iteration
that ends without closing out is not finished.

**With the default `Merge policy: never`, the loop never merges anything.**
Merging follows the adapter's `Merge policy`, a per-repo decision. Teams
differ in how much they trust an unattended merge, so the default is `never` and
`clean-verdict` is opt-in, set explicitly in the repo's adapter. Under `never` the
loop never merges. Under `clean-verdict` the orchestrator, and only the
orchestrator, merges a story's own pull request with the forge's merge verb, merge
commit only, after the closeout commit is on the branch and `"$LS" merge-gate`
prints `merge`. A story in any of the adapter's `Human-only categories` is never
merged by the loop. An escalation at or above the threshold stops for a human
before any of this is considered.

**It never authorizes:** any other merge (an implementer may merge its parent into
its own story branch to freshen it, never rebase, and merges into no other branch), force push, rebase, reset, amend, tag
operations, branch deletion, any direct push to the base branch or to
`main`/`master`/`develop`, git config changes, hook bypass, or edits to `tasks/`
in the main checkout. The rule covers tracked edits: the log and a verifier's
verdict file written into the checkout are untracked local state. It includes the adapter: `tasks/story-loop.md` is written on a
branch and lands through a tasks-only pull request. A subagent that believes it needs one of these must return
`blocked` with the reason instead.

## The orchestrator reads nothing

You are the orchestrator. You **must not** read source files, diffs, verdict
bodies, test output or CI logs, and you **must not** implement or edit story
contents. The only write exceptions are the fixed state-folder moves and
tasks-only state commits in [orchestrator.md](orchestrator.md), and the merge the
adapter's merge policy allows. Derive every decision from
story headers and the log using `scripts/loop-state.sh`. Full contract and budget:
[orchestrator.md](orchestrator.md). That script has its own tests:
`scripts/selftest.sh` and `scripts/e2e-chain.sh`, both safe to run anywhere.
`scripts/anchor-check.sh` keeps the code anchors stories cite honest, tested by
`scripts/anchor-selftest.sh`. It is not an iteration step: run `resolve` from the repo
root when filing or grooming stories, and `lost <rev>` after a change that renamed or
deleted files, to find stories whose anchors broke.

## One iteration

Paths are relative to the consumer repo. Set `LS` once to `scripts/loop-state.sh`
in this skill's own directory, the one that holds this `SKILL.md`, and reuse it; the
deployed skill directory differs per host, so resolve it rather than assume it.

1. **Load the adapter.** `tasks/story-loop.md` holds the queue, the chain, the
   forge, the verifier, the merge policy and the local rules; `"$LS" adapter-check`
   validates it and prints every effective value. Read `Queue root`, `Log path`
   and `Verdict dir` with `"$LS" adapter-path <adapter> <field>`, never with
   `adapter`: relative values resolve against the adapter's repo root, which is
   what lets a member repo point at a workspace queue. Missing? Probe, then write it
   on its own branch and open a tasks-only pull request, never in the main checkout
   (with `Forge: none`, push the branch and stop for the operator); this iteration
   reads it from that branch: [adapter.md](adapter.md). In a workspace queue, the story's `**Repo:**` header
   picks the repo whose adapter governs the rest of the iteration. If the adapter exists but its untracked log is missing,
   stop for operator reconciliation before selecting work; a fresh checkout must
   not recreate state while prior branches or pull requests may still be active.
   If it declares `Teams`, run steps 2-7 once per team, concurrently, one story in
   flight per team: [teams.md](teams.md).

2. **Select.** `"$LS" eligible <queue-root> <log>` prints
   `id<TAB>deps<TAB>effort<TAB>path`, or nothing; with teams add
   `--team <name> <adapter>`. Empty does not mean drained, so
   run `"$LS" stalled <queue-root> <log>` and log what it names before concluding
   otherwise: [orchestrator.md](orchestrator.md).

3. **Compute the parent.** `"$LS" parent <log> <base> <mode> <deps>`. This is the
   step that makes pull requests stack. Never let the implementer choose its own
   base. Read [chain.md](chain.md) before changing anything here.

4. **Spawn the implementer**, clean context and isolated tree, as the adapter's
   `Implementer agent`, using the fixed template in
   [implementer-brief.md](implementer-brief.md). Host specifics:
   [runner-claude.md](runner-claude.md), [runner-codex.md](runner-codex.md),
   [runner-opencode.md](runner-opencode.md).

5. **Check the return.** `"$LS" check-base <parent> <returned-BASE>`. Non-zero is
   `blocked :: unstacked`, not a warning: [chain.md](chain.md).
   The orchestrator owns native stack linking. Run
   `"$LS" native-stack <forge> <mode> <teams:yes|no> <parent> <base> <Native stacks>`
   after resolving a merged parent to the base. A skip is normal for roots, DAG,
   teams, non-gh forges, `Native stacks: off` and a host without the `gh stack`
   extension; keep their computed bases. On `link`, follow
   [native-stacks.md](native-stacks.md) before verification. Invalid input blocks the
   iteration; an unavailable stacks API skips linking with a note in the log row.

6. **Verify**, if the adapter names a verifier. Wait for CI to leave pending
   (the implementer may return `CI: pending`), dispatch by PR number with a fresh
   context, then route BLOCKING holds on the returned escalation score: at or above
   the adapter's threshold stop for a human, below it relay the returned `BLOCKERS`
   value verbatim to the same warm implementer. Surface `CONCERN` verbatim whatever
   the score; it never changes the route. [verify.md](verify.md).

7. **Move the story file** per the folder state machine, merge if the merge policy
   and gate allow, then `"$LS" append <log> <9 fields>` exactly one row, with
   its Notes starting `merged` when it merged. The row comes last.

   On a clean verdict, that move is part of the
   [closeout commit](orchestrator.md#closeout): story into `6_completed`, verdict
   copied from the `PATH` the verifier returned into the adapter's `Verdict archive`
   (or deleted, when that is `none`), `tasks/` only, on the branch, by the adapter's `Closeout by`. A finished iteration leaves
   nothing for the next one to file.

   **Closeout before merge.** Under `Merge policy: clean-verdict`, merge only after
   the closeout commit is pushed and CI is green on that head; a closeout deferred
   past the merge has no branch left to ride.

8. **Stop or continue** against the conditions below.

## Stop conditions

- Queue empty, and nothing reported by `stalled`, and no team has a story in flight
- 2 consecutive stories return `blocked`; with teams this stops that team only
- A verifier still returns HOLD after remediation round 2
- A verifier returns `HOLD_REASON: EVIDENCE`, always, `Review list` or not
- A verifier returns `MERGE AFTER FIXES` with `Remediate should-fix: off` (the
  default), or still returns it after round 2, and the adapter names no `Review list`
- A story asks the operator to sign something off and the adapter names no `Review list`
- **A verifier returns an escalation score at or above the adapter's threshold.**
  Stop before remediating, not after: the point of the threshold is that a human
  sees the finding before anything responds to it
- The named verifier cannot be dispatched (`judge unavailable`): never substitute a
  fork, a generic agent or a failed dispatch for a verdict
- The authorization boundary above is hit
- User interrupt

With teams, a team with nothing eligible idles; it does not stop the loop. The other
stops halt new dispatch in every team and let in-flight work finish its phase.

Every stop writes a final log row naming which condition fired. If a story
completed in the same iteration, that is two rows: the story's, then the stop.

A stop that needs the operator tells them with an operator brief per item: id,
title, one line on what it is, a link to where the file lives now, and the ask.
Format: [orchestrator.md](orchestrator.md#operator-brief).

Open defects not yet fixed: [KNOWN-ISSUES.md](KNOWN-ISSUES.md).

## Checklist

- [ ] Adapter loaded or written; nothing asked twice
- [ ] Parent computed by the orchestrator, never by the implementer
- [ ] Returned `BASE` checked against the supplied parent
- [ ] Exactly one log row appended, including for blocked and escalated stories
- [ ] BLOCKING route taken from the escalation score alone, never from the summary
- [ ] Evidence holds stopped outside score routing; `CONCERN` surfaced verbatim
- [ ] MERGE AFTER FIXES and sign-offs stopped, or listed when a `Review list` exists
- [ ] Merged only under `clean-verdict`, after closeout, with `merge-gate` printing `merge`
- [ ] Story bodies opened: zero. Verdict files opened: zero. Diffs read: zero
- [ ] With teams: one story in flight per team, every idle team dispatched on each wake
- [ ] With lanes < teams: phase 1 touched no shared runtime; lanes granted oldest first
- [ ] Lock released only after merge or final routing and `STACK: down` or `none`
- [ ] No log row for a `phase1` return; merges serialized; behind branches merged, never rebased
- [ ] Clean verdict closed out on the branch: story filed, verdict archived or deleted,
      nothing left uncommitted in the main checkout for the next iteration
