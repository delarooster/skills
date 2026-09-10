# Orchestrator Contract

## Prohibitions

**MUST NOT** read source files, diffs, verdict bodies, test output or CI logs.
**MUST NOT** implement, commit, push or edit story files itself.

The point is not tidiness. The orchestrator that never reads a diff cannot talk
itself into believing a story landed. It sees only what the subagent claims and
what the verifier independently found, and it verifies the one claim it can.

## Per iteration

1. Read the log and the story index. `"$LS" index <queue-root>` emits
   `id<TAB>deps<TAB>effort<TAB>path` and nothing else. Never open a story body.
2. Select the next eligible story.
3. Compute its parent branch. See [chain.md](chain.md).
4. Spawn the implementer, spawn the verifier, relay bounded findings between them.
5. Check the returned `BASE` against the parent supplied.
6. Move the story file between state folders per the plan-project state machine.
7. Append exactly one row to the log.
8. Decide whether to continue.

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

"Per the state machine" is not enough to act on. The mapping from outcome to
folder is fixed:

| Outcome | Move the story file to | Why |
|---|---|---|
| `landed`, verifier not yet run | `4_in-review` | The pull request is open and unjudged. Work is done; review is not |
| `landed`, clean verdict | `6_completed` | In the closeout commit, on the branch. See below |
| `partial` | `4_in-review` | Same state, with the shortfall recorded in the log row |
| `blocked` | `5_blocked` | Including underspecified, unstacked, bad return, and unsatisfiable dependency |

`6_completed` means merged, or on a branch whose only remaining step is the
merge. The loop never merges, but it does not leave the filing to "whoever merges
the chain" either -- that is how stories end up shipped and still sitting in
`1_backlog`. When the verifier returns a clean verdict, the closeout commit in
`commands/git.md` moves the story from `4_in-review` to `6_completed` **on the
branch**, so the ledger lands at the same instant the merge does and dies with the
branch if the pull request is abandoned. **The folder is load-bearing either
way.**
The log is untracked and starts empty on a fresh checkout, so `6_completed` is the
only durable record that a story finished, and `"$LS" completed <queue-root>`
reads it to satisfy dependencies. Move merged stories there and nowhere else.

**Never archive story files out of the queue root.** Moving them to
`tasks/archive/` or any path outside `<queue-root>` deletes them from the
dependency ledger, and every story that depends on one is then reported
`dependency unsatisfiable` forever. The queue root is the ledger; archiving is
for session records, not for stories. `3_in-progress` is optional: use
it while an implementer is in flight if you want a crash to be visible, but move
the file out before appending the log row, so a resumed run sees a consistent tree.

Move the file **after** the implementer returns, never before. A story moved on
spawn and then abandoned by a crashed subagent is invisible to both the queue and
the log.

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
is unsatisfiable. Before acting on a `stalled` report, check that the named
dependency is not simply a finished story filed somewhere other than
`6_completed` -- that is a bookkeeping defect in the queue, not a blocked story,
and logging it as blocked buries it.

## Implementer subagent

Clean context, isolated tree, so it contends with neither the shared checkout nor
the verifier. Brief it with the fixed template in
[implementer-brief.md](implementer-brief.md) and nothing else. Do not compose a
brief from memory: the omitted-parent failure in [chain.md](chain.md) is what that
produces.

Its job ends at "pull request is open against the parent and CI has left
pending." It does not merge, and it does not choose its own base.

## Return contract

The nine fields, and the brief that demands them, are in
[implementer-brief.md](implementer-brief.md). It is the template you send, so it
carries the contract verbatim; do not restate the fields here or anywhere else.

Validate on receipt. A non-conforming return is rejected and re-requested once,
then logged `blocked :: bad return`. A subagent that returns a diff has defeated
the whole design, so treat an oversized return as non-conforming too.

Two fields are checked, not trusted: `BASE` against the parent you supplied (see
[chain.md](chain.md)), and `AC` against the story's own checkbox count.

## Verifier subagent

Optional. If the adapter names one, dispatch it by pull request number with
today's date, in a fresh context every round including remediation rounds. It
never becomes the implementer's assistant. If the adapter names none, skip the
stage silently and log `VERDICT: absent`. Do not offer to create one.

**Wait for CI before the first dispatch.** Poll the checks until they leave
pending or roughly four minutes pass. A verifier dispatched at pull-request-open
reports the one gate with real signal as unverifiable, which is worse than not
running it. If checks never appear, dispatch anyway and record their absence; the
absence is itself a finding.

Read back only five fields: verdict, blocking count, **escalation score**,
one-line summary, verdict path. Never open the verdict file.

## Escalation

The verifier scores each blocking finding 0-10 and returns the maximum as
`ESCALATION`, or 0 when nothing blocks. The adapter's **escalation threshold**
(default **8**) splits the routing:

| Score | Route | Action |
|---|---|---|
| **>= threshold** | HUMAN | Stop the loop. Log `escalated :: <score>` with the PR and the one-line summary, and surface it. Do not remediate and do not start the next story |
| **< threshold** | AUTO | Bounded remediation below, then continue |
| **0** | AUTO | Nothing blocking. Log and continue |

**Route on the number, never on the summary.** The summary is one line of prose you
are allowed to relay; it is not evidence and must not change the route. If the
verifier returns no `ESCALATION` field, treat it as a non-conforming return and
re-request once, then log `blocked :: bad return`. Do not infer a score from the
verdict, and do not substitute your own judgement of severity: you have not read
the findings, which is precisely why you are trusted to route them.

**The threshold spends a human's attention.** Every escalation is a claim that a
person must look now. Every non-escalation is a claim that two automated rounds
will do. Both are expensive when wrong, in opposite directions, so the scale is
anchored in the verifier definition rather than left to taste.

Escalation never authorizes a merge, and it never removes the human from the merge.
It decides only who reads the verdict.

**Relay the scorer's `CONCERN:` line verbatim whatever the score, and never let it
change the route.** A score measures how badly the pull request breaks the product;
some findings matter for reasons the scale cannot express and will always score 0.
A pre-existing defect the work merely uncovered, a fabricated citation, a claim the
verifier could find no evidence for: the diff can be clean while the narrative
around it is false. Relaying that line costs one line of output and is the only
thing standing between a faithful score and a scale that gets inflated so somebody
notices.

## Remediation rounds

Blocking findings go back to the **same** implementer instance, warm, not to a new
agent. A fix on warm context costs a fraction of a fresh spawn.

If no warm implementer exists, because the pull request was opened by an earlier
run or by hand, spawn a fresh one briefed only on the blocking findings and the
pull request number. Say so in the log row: a cold remediation is a different and
weaker thing than a warm one, and the row is the only place that distinction
survives.

At most **2** rounds. Only findings the verifier marks blocking are actionable.
The implementer may not edit the verdict file. After round 2 the story lands with
whatever is left, and the leftovers go in the log row.

The risk being managed: a verifier that sees its own prior verdict addressed
starts grading the response instead of the code. Fresh verifier context per round
is what prevents that, and it is not negotiable.

## Log

One file, path from the adapter, deliberately untracked, because the chain roots
at the base branch and a tracked log would reset itself every chain.

Columns: `Story | Outcome | PR | Branch | Base | AC | CI | Verdict | Notes`.
`Branch` and `Base` together are the chain.

**Escalation rides in the `Verdict` cell**, as `<verdict>(<score>)`: `HOLD(9)`,
`MERGE AFTER FIXES(4)`, `MERGE(0)`, `absent` when no verifier is configured. It is
not a tenth column, deliberately, because `LOG_COLS` in `loop-state.sh` is asserted
by `scripts/selftest.sh` and a schema change there costs more than it buys. A run
that escalated is then greppable: `grep -E '\((8|9|10)\)' <log>`.

Append with:

```bash
"$LS" append <log> <story> <outcome> <pr> <branch> <base> <ac> <ci> <verdict> <notes>
```

Empty fields become `-`. Cold start reads this file and nothing else.
