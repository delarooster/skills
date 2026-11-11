# Verify, Merge, Remediate

Step 6 of an iteration. The prohibitions in [orchestrator.md](orchestrator.md) hold
throughout: the orchestrator reads no verdict body.

## Verifier subagent

Optional. If the adapter names one, dispatch it by pull request number with
today's date, in a fresh context every round including remediation rounds. It
never becomes the implementer's assistant. If the adapter names none, skip the
stage silently and log `VERDICT: absent`. Do not offer to create one. With `forge:
none`, dispatch by branch and parent (it judges `parent...branch`) only if your
verifier supports that. A verifier that needs a pull request number and the forge
CLI, as the `pr-judge` in the public skills repo does, cannot run without a forge:
log `VERDICT: absent` with that reason.

**Wait for CI before the first dispatch.** Wait on the forge's checks verb, with one
background command as in [orchestrator.md](orchestrator.md), until they leave pending
or the adapter's `CI wait` passes. A verifier dispatched at pull-request-open
reports the one gate with real signal as unverifiable, which is worse than not
running it. If checks never appear, dispatch anyway and record their absence; the
absence is itself a finding.

Read back the return fields, in the verifier definition's order: `VERDICT`,
`HOLD_REASON`, `BLOCKING`, **`ESCALATION`**, `BLOCKERS`, `CONCERN` (optional),
`SUMMARY`, `PATH`. Never open the verdict file. It lives at the returned `PATH`; a
relative `PATH` resolves against the directory the verifier ran in. A verifier that
takes an output directory writes into the adapter's `Verdict dir` (read with
`adapter-path`). One that writes `tasks/reviews/pr-<N>.md` relative to where it
runs, as the `pr-judge` in the public skills repo does, writes into the checkout:
with that judge the verdict file is untracked local state, which the closeout copies
into `Verdict archive` or deletes.

**`CONCERN` is a second channel, not a route.** Surface it to the operator
verbatim, whatever the score, and put it in the log row's Notes when it is not
`none`. It never changes the route. It carries what the scale deliberately scores
0: a pre-existing defect the pull request uncovered, a fabricated citation, a claim
evidenced nowhere. Inflating a score so someone notices breaks the scale; the
channel is what makes that unnecessary. A verifier that returns no `CONCERN` line
is read as `CONCERN: none`. To make a verifier report concerns, put the line in its
definition, not in the dispatch: a rule carried in dispatch text dies with the
session that wrote it.

## Escalation

If a story asks for an external evaluation as proof, or its pull request cites
one, tell the verifier where that evidence lives and which exact run it is. The
verifier checks that the evidence matches the base and head under review, covers
what it claims and cites real sources; the orchestrator still reads only the return
fields. A passing job is not a verdict, and missing or stale evidence never starts
a costly re-run on its own. Ordinary stories gain no extra gate from this.

The verifier is the sole score authority. It scores each blocking finding 1-10
from direct evidence and returns the maximum as `ESCALATION`, or 0 when nothing
blocks. The orchestrator never recomputes that score. Only a validated
`HOLD_REASON: BLOCKING` enters the table. The adapter's **escalation threshold**
(default **8**) splits that routing:

| Score | Route | Action |
|---|---|---|
| **>= threshold** | HUMAN | Move the story to `5_blocked`, stop the loop, log `escalated :: <score>` with the PR and one-line summary, and surface it as an [operator brief](orchestrator.md#operator-brief). Do not remediate or start the next story |
| **1 <= score < threshold** | AUTO | Bounded remediation below, then continue |

**Route on the number, never on the summary.** The summary is one line of prose you
are allowed to relay; it is not evidence and must not change the route. If the
verifier returns no `ESCALATION` field, treat it as a non-conforming return and
re-request once, then log `blocked :: bad return`. Do not infer a score from the
verdict, and do not substitute your own judgement of severity: you have not read
the findings, which is precisely why you are trusted to route them.

`HOLD_REASON: EVIDENCE` is not a score route. Move the story to `5_blocked`, log
`blocked :: evidence unavailable`, surface an operator brief, and stop before
remediation or the next story. `MERGE AFTER FIXES` is also outside score routing, and what happens next is
the adapter's `Remediate should-fix`:

| `Remediate should-fix` | Action |
|---|---|
| `off` (default) | Move the story to `5_blocked`, log `blocked :: non-blocking fixes`, surface an operator brief, and stop |
| `on` | Bounded remediation below, on the SHOULD FIX findings, then re-judge with a fresh verifier. A resulting `MERGE` goes to the merge policy; `MERGE AFTER FIXES` after round 2 stops as `off` does |

With a [review list](#review-list), a MERGE AFTER FIXES that would stop under either
row does not stop: it goes on the list and the story is treated as clean.

With `off`, the operator may answer that stop by authorizing remediation of those
findings for that one story. Send the returned `PATH` to the warm implementer, as in a
should-fix round below, count the round against
the cap of 2, and verify again in a fresh context. The authorization does not carry to
the next story, and a finding that is only a missing process record (no red-first
commit, say) can be accepted as is rather than remediated.

Require `EVIDENCE` with a HOLD verdict, zero blocking count, zero score, and
`BLOCKERS: none`; `BLOCKING` with a HOLD verdict, positive count, positive score,
and a BLOCKERS value other than empty or `none`; and `NONE` with zero count, zero
score, and `BLOCKERS: none` on MERGE or MERGE AFTER FIXES. A missing `CONCERN`
line means `none` and is never grounds to reject a return. Require the returned verdict path
to exist without opening it, resolving a relative `PATH` as above. Reject any other combination once for
correction, then log `blocked :: bad return`.

**The threshold spends a human's attention.** Every escalation is a claim that a
person must look now. Every non-escalation is a claim that two automated rounds
will do. Both are expensive when wrong, in opposite directions, so the scale is
anchored in the verifier definition rather than left to taste.

Escalation never authorizes a merge. It decides only who reads the verdict; the
merge policy decides the rest.

## Review list

Optional adapter field: a file path outside every checkout. With it, the loop asks the
operator nothing below the escalation threshold.

| Event | Without a list | With a list |
|---|---|---|
| `MERGE AFTER FIXES`, score below threshold, not cleared by should-fix remediation | stop, operator brief | treat as clean, append one line |
| A story or repo rule asks the operator to sign off copy, a translation or a migration, and the verifier passed it | stop, ask | take the implementer's default, append one line |

One line per item: `- [ ] <id> PR <n> | <what was accepted> | <verifier summary>`. Mark a
line `RELEASE-RISK` when it could harm production data or users. The list gates the
release, not the loop: every open line for a release is cleared with the operator
before its tag, and a `RELEASE-RISK` line blocks the tag. A listed story still meets
the merge policy on its own terms: `merge-gate` never sees a listed MERGE AFTER FIXES
as `MERGE`, so under `clean-verdict` it waits for a person. Escalation, evidence holds,
exhausted BLOCKING remediation and the authorization boundary still stop the loop.

## Merge

Under `Merge policy: never`, skip this section. Under `clean-verdict`, after the
closeout commit is pushed and its CI has left pending:

```bash
"$LS" merge-gate <policy> <VERDICT> <BLOCKING> <ESCALATION> <ci> <AC> <forwarded> \
  "$("$LS" categories <story>)" "<Human-only categories>"
```

`forwarded` is `yes` only when every unticked criterion already has its own filed
story; filing it is a filer agent's job, not the orchestrator's pen. On `merge`,
run the forge's merge verb ([chain.md](chain.md)), merge commit only, and start the
log row's Notes with `merged`. On `hold :: <reason>`, leave the pull request open, note
the reason, and continue: a held merge is a human's queue, not a blocked story.

Merging as each verdict comes back clean keeps the chain shallow: the next story's
parent is then the base ([chain.md](chain.md), "A merged parent is the base"), and
two stories editing one file resolve at the merge instead of piling up.

## Remediation rounds

Relay the verifier's `BLOCKERS` value verbatim to the **same** implementer instance,
warm, not to a new agent. A fix on warm context costs a fraction of a fresh spawn.

If no warm implementer exists, because the pull request was opened by an earlier
run or by hand, spawn a fresh one briefed only on the blocking findings and the
pull request number. Say so in the log row: a cold remediation is a different and
weaker thing than a warm one, and the row is the only place that distinction
survives.

For a should-fix round there is no `BLOCKERS` value to relay: send the returned
`PATH` and tell the implementer to address the verdict's SHOULD FIX findings. The
implementer reads the file; the orchestrator still does not.

At most **2** rounds. Only findings the verifier marks blocking are actionable,
plus SHOULD FIX when `Remediate should-fix: on`.
The implementer may not edit the verdict file. If the verifier still returns HOLD
after round 2, move the story to `5_blocked`, log `blocked :: remediation
exhausted` with the leftovers, and stop.

The risk being managed: a verifier that sees its own prior verdict addressed
starts grading the response instead of the code. Fresh verifier context per round
is what prevents that, and it is not negotiable.
