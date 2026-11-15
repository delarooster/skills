# Orchestrator Contract

## Prohibitions

**MUST NOT** read source files, diffs, verdict bodies, test output or CI logs.
**MUST NOT** implement or edit story contents, or write `tasks/` in the main
checkout. It may perform only the fixed story file moves below, on the story
branch; the closeout commit when the adapter's `Closeout by` is `orchestrator`; the
merge the adapter's merge policy allows; native stack linking (`gh stack link`);
creating the story branch and worktree where the runner says the orchestrator does
(Codex, OpenCode); a missing adapter on its own branch with a tasks-only pull request
(with `Forge: none`, push that branch and stop for the operator); the
[handoff write](#session-state); and, with teams, writes to the stack lock
file.

## Per iteration

The steps are in [SKILL.md](SKILL.md#one-iteration). `"$LS" index <queue-root>`
emits `id<TAB>deps<TAB>effort<TAB>path` and nothing else; never open a story body.

A missing log under an existing adapter stops the loop: a fresh checkout cannot tell
which queued files already have active branches or pull requests. Continue only
after the operator restores the log or confirms the queue has no active work, then
initialize a new one. A genuine first run, creating the adapter, is exempt.

If you ever need a story body to decide, the story is underspecified. Log
`blocked :: underspecified` and move on. That is a planning defect, and repairing
it here would hide it.

**Budget, counted rather than estimated.** Per iteration: story bodies opened,
zero. Verdict files opened, zero. Diffs read, zero. Test output read, zero. These
are countable while the run is happening, unlike a share of the context window, and
they are the only things that make a long queue unaffordable. A nonzero count means
the iteration has already failed its contract, whatever else it produced.

## Queue membership

`2_ready` first, then `1_backlog`. Stories in `3_in-progress`, `4_in-review`,
`5_blocked`, `6_completed` or `7_cancelled` are not queue members. Story id comes
from the leading token of the first `# ` heading, falling back to the filename
stem.

## Where the story file lands

The mapping from outcome to folder is fixed:

| Outcome | Move the story file to | Why |
|---|---|---|
| `landed`, verifier not yet run | `4_in-review` | The pull request is open and unjudged. Work is done; review is not |
| `landed`, clean verdict | `6_completed` | In the closeout commit, on the branch. See below |
| `partial` | `4_in-review` | Same state, with the shortfall recorded in the log row |
| `blocked` | `5_blocked` | Including underspecified, unstacked, bad return, unsatisfiable dependency, evidence HOLD, MERGE AFTER FIXES with no review list, and exhausted remediation |
| `escalated` | `5_blocked` | A score at or above the escalation threshold; a human decides |

`6_completed` means merged, or on a branch whose only remaining step is the
merge. The [closeout commit](#closeout) files it there **on the branch**, so the
ledger lands with the merge and dies with an abandoned pull request; never leave
filing to "whoever merges the chain". **The folder is load-bearing.** The log is untracked and starts empty on a fresh checkout, so `6_completed` is the
only durable record that a story finished, and `"$LS" completed <queue-root>`
reads it to satisfy dependencies. Move merged stories there and nowhere else.

**Never archive story files out of the queue root.** Moving them to
`tasks/archive/` or any path outside `<queue-root>` deletes them from the
dependency ledger, and every story that depends on one is then reported
`dependency unsatisfiable` forever. `3_in-progress` is optional and only ever on
the story branch: an implementer may move its own file there while it works, and
it leaves before the log row is appended, so a resumed run sees a consistent tree.

Move the file **after** the implementer returns, never before. A story moved on
spawn and then abandoned by a crashed subagent is invisible to both the queue and
the log.

Every move is made on the story branch, never in the main checkout, without
opening the story body. When a story branch exists, persist the move there in a
tasks-only commit and push, made by whoever `Closeout by` names; this state commit
does not trigger another verification because it cannot change reviewed behavior.
When no branch exists (a story blocked before branching), do not move the file:
the log row records the outcome, and the operator brief says where the file still
is.

## Closeout

The last commit on a story branch after a clean verdict. It touches `tasks/` only:
the story file into `6_completed`, the verdict file at the `PATH` the verifier
returned copied into the adapter's `Verdict archive` (with `none`, that file is
deleted instead and nothing is copied), and any per-story state file the
repo's notes name. It is pushed to the story branch, never to the base, and an
iteration that ends without it is not finished.

| `Closeout by` | Who commits it |
|---|---|
| `orchestrator` (default) | The orchestrator, in the story's worktree. No other writes |
| `implementer` | The warm implementer, on a message naming exactly those moves; cold, a fresh implementer briefed with only the closeout. Use it where the repo's git rules let only implementers commit |

## Nothing eligible is not nothing left

`eligible` returns empty both when the queue is drained and when everything
remaining is waiting on a dependency. Before concluding the queue is done:

```bash
"$LS" stalled <queue-root> <log>
```

It lists stories whose dependencies can **never** be met, distinguishing them from
stories merely waiting on a dependency still in the queue. Log each one
`blocked :: dependency unsatisfiable` with the named dependency. Without this
step a story with a typo'd or deleted dependency vanishes silently while the queue
reports itself drained.

**A story in `6_completed` on a stacked branch is a satisfied dependency**, and
should be. The next implementer builds on that branch, so the work is genuinely
present in the tree it inherits -- more true than `4_in-review`, which says the
work exists but refuses to let anything use it. On the base branch the story stays
where it was until the merge, which is also correct: nothing there can see it yet.

**Two ledgers answer "is this dependency done?"**, in order: a `landed` or
`partial` row in the log, then presence in `6_completed`. A dependency in neither
is unsatisfiable. A trim ([Log](#log)) drops only `stop` rows, so neither ledger
loses a story. Before acting on a `stalled` report, check that the named
dependency is not simply a finished story filed somewhere other than
`6_completed` -- that is a bookkeeping defect in the queue, not a blocked story,
and logging it as blocked buries it.

## Implementer subagent

Clean context, isolated tree, so it contends with neither the shared checkout nor
the verifier. Brief it with the fixed template in
[implementer-brief.md](implementer-brief.md) and nothing else. Do not compose a
brief from memory: the omitted-parent failure in [chain.md](chain.md) is what that
produces.

Its job ends at "pull request is open against the parent"; it does not wait on CI.

**`CI: pending` is a valid return.** It means the implementer stopped waiting, not
that anything failed. Before dispatching the verifier, wait on the forge's checks
verb ([chain.md](chain.md)) until they leave pending or `CI wait` passes, and log
the CI cell from what the checks say then, not from the return. Wait with one
background command and act on its exit, never by polling turn after turn: every
orchestrator turn re-sends the whole context. If the checks go red, message the
warm implementer.

## Return contract

The ten fields, and the brief that demands them, are in
[implementer-brief.md](implementer-brief.md). Do not restate the fields elsewhere.

Validate on receipt. A non-conforming return is rejected and re-requested once,
then logged `blocked :: bad return`. A subagent that returns a diff has defeated
the whole design, so treat an oversized return as non-conforming too.

One field is checked, not trusted: `BASE` against the parent you supplied (see
[chain.md](chain.md)). `AC` is logged as returned; `merge-gate` reads it, so an
unmet or malformed count holds the merge.

## Verify, merge, remediate

Read [verify.md](verify.md) at step 6, once the implementer has returned: the
verifier dispatch, its return contract, escalation routing, the merge gate and
remediation rounds.

## Operator gates

When the operator asks to be pinged or told before a step (a first run, a deploy, a
delete, a scale-down, anything they want to watch), stop on the host's question tool
with one clear choice, recommended option first (for example "I'm online, start" /
"Not yet"), and do no further work past the gate. Never leave a "let me know" status
line and keep working: it scrolls away, and the operator finds the orchestrator
waiting only after scrolling up. While waiting on background agents, do not emit
repeated status chatter.

## Operator brief

"Surface" means a brief, not an id. In anything the operator reads, tables included,
name each story, pull request or decision first by what it is in plain words, then its
id as a clickable link; an id never stands alone: "Retry failed card payments
([<id>](<story url>))".

**No machine numbers.** Never show a CI run, build or job id: name the run by what it
is ("the staging deploy", "the mobile store build") and link it if that helps. A git
hash appears only when the operator needs it to act, as the 7-character short SHA.

Anything that asks the operator to act -- an escalation, a hold, a stop, a pending
decision, a newly filed item they must rule on -- carries one brief per item:

| Field | Source |
|---|---|
| Title and id | The story's `# ` heading, which the index already reads |
| What it is | One plain-language line, plus the verifier's summary when there is one |
| Links | The pull request's forge URL; the story file as a forge URL on the branch where it lives **now**, or its absolute path when unpushed; the verdict or decision the ask rests on |
| The ask | The single decision or action needed, its options, recommended one first |

**With a `Review list`, the asks its table names do not block the loop**
([verify.md](verify.md#review-list)): write each at once as one line in that list's
format, repeat it under a closing "Needs you" section, and keep working on
everything that does not depend on the answer. Every other stop condition still
stops. On the next wake, read the list for answers before asking again.

Resolve links when writing, from the branch stories stack onto, not a checkout that
may be behind it: story files move, and a stale link costs the operator a search.
Writing the brief opens no story body.

## Teams and lanes

Only when the adapter declares a `Teams` table: [teams.md](teams.md).

## Session state

Before a context clear or compaction, at every stop, and when the operator says a
refresh is coming, write the state first. On disk at their adapter paths: the row of each
unlogged story past its merge, or its final routing when the loop will not merge it,
and new `Review list` asks. When the adapter's repo notes name a handoff file under `tasks/`,
overwrite it with current state, unlogged stories included, on its own branch
through a tasks-only pull request, reusing an open one (with `Forge: none`, push
only). This write never stops the loop. A fresh session resumes from those alone;
memory and the transcript hold at most a pointer.

## Log

One file, path from the adapter, deliberately untracked, because the chain roots
at the base branch and a tracked log would reset itself every chain.

Columns: `Story | Outcome | PR | Branch | Base | AC | CI | Verdict | Notes`.
`Branch` and `Base` together are the chain. A workspace queue writes `Branch` as
`<repo>:<branch>` ([adapter.md](adapter.md)).

`Outcome` is one of `landed`, `partial`, `blocked`, `escalated` or `stop`. The
shorthand `blocked :: <reason>` and `escalated :: <score>` means that outcome with
the rest in `Notes`. `escalated` is a story stopped for a human at or above the
escalation threshold; its file goes to `5_blocked` like a blocked one. `stop` is the
final row a stop condition writes, with `-` for the story. Only `landed` and
`partial` advance the chain. A row records its merge with a `Notes` cell that starts
with `merged`. `append` trims only `stop` rows older than the newest 50 rows. Every
story row stays, merged ones included, because `eligible` excludes a story only by
its row and a queue root may not yet show the merge. `depth` counts only unmerged
chained rows.

**Escalation rides in the `Verdict` cell**, as `<verdict>(<score>)`: `HOLD(9)`,
`MERGE AFTER FIXES(0)`, `MERGE(0)`, `absent` when no verifier is configured. It is
not a tenth column: `LOG_COLS` in `loop-state.sh` is asserted by
`scripts/selftest.sh`. Find escalations with `grep -E '\((8|9|10)\)' <log>`.

Append with:

```bash
"$LS" append <log> <story> <outcome> <pr> <branch> <base> <ac> <ci> <verdict> <notes>
```

Empty fields become `-`.

## Cost

The orchestrator is the most expensive context in the run; spend it on routing
only.

- **Model tiers come from the adapter.** Dispatch implementer, verifier and filer
  at their configured tiers. Never resume a fork of the orchestrator to file or
  groom stories: it carries the whole session's context for a bookkeeping task.
- **Heavy CI is not per-change**, and the verifier runs on every pull request and triggers
  no workflow: [adapter.md](adapter.md) (`CI`, `Full runs at`).
- **Rules live in definitions, not dispatches.** A rule that an agent must follow
  goes in its agent definition or a brief slot. Restating it in each dispatch
  costs tokens every time and survives no session.
