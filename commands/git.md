---
description: Full git push cycle — verify feature branch, commit staged changes with a meaningful message, push, open a PR if one doesn't exist, and dispatch an independent judge if the repo has one
---

Ensure we're on a feature branch, if not create one, and then make a meaningful
commit, push to the remote, and if there's not a current pr, open one.

## Then: judge the PR, if this repo has a judge

Invoking `/git` is the explicit authorization for the commit and push above.
It is **not** authorization to act on anything the judge finds.

**Guard.** Only do this when `.claude/agents/pr-judge.md` exists in the repo or
the installed global agent `~/.claude/agents/pr-judge.md` exists. Most repos have
no judge; skip the whole section silently there. Do not offer to create one.

**Wait for CI before judging.** At the moment a PR opens, its checks have not
run. A judge dispatched immediately reports the one gate with real signal as
unverifiable, which is worse than not running it. Poll `gh pr checks <N>` until
the checks leave a pending state, or roughly four minutes have passed, then
dispatch. If checks never appear, dispatch anyway and say they were absent —
that absence is itself a finding worth a verdict.

**Dispatch.** Spawn the `pr-judge` agent against the PR number. Tell it today's
date. It writes its verdict to `tasks/reviews/pr-<N>.md` and that file is the
deliverable.

**Re-judge on later pushes too**, not only at creation. A PR that gained commits
since its last verdict has a stale verdict. Compare against the head sha recorded
in the existing verdict file; if it differs, judge again and overwrite.

**One exception, and it is what makes the cycle terminate: a closeout commit does
not trigger a re-judge.** It changes the head sha like any other commit, so this
rule read literally would judge it, and the judge would write a fresh
`tasks/reviews/pr-<N>.md`, which would need closing out, forever. A closeout
touches `tasks/` and nothing else -- it cannot change anything a verdict is about.
Verify that scope before committing rather than asserting it, then stop. Anything
outside `tasks/` is not a closeout and is judged normally.

## Then: close out the cycle

A pull request is not finished when it is approved. It is finished when nothing
it created is still lying around waiting for a human to file it. Leave that
filing to "whoever merges", and it does not happen: shipped stories sit in
`1_backlog` pretending to be work, verdicts pile up in `tasks/reviews/`, and the
next cycle starts by cleaning up after the last one.

**Invoking `/git` authorizes this. Do not ask for it.** The closeout is the tail
of the cycle, not a response to the judge, and the rule below about findings being
the user's to triage does not reach it -- filing your own paperwork is not acting
on a finding. A closeout that waits to be nudged is the mess it exists to prevent,
one round later.

**Only on a clean verdict** -- MERGE, zero blocking findings. A MERGE AFTER FIXES
gets fixed and re-judged first, and *that* fix does need the user, because it
changes reviewed behaviour. The closeout is the last thing on the branch, never a
way to tidy past an open finding.

**One commit, on the branch, before the merge.** It contains:

- The story file moved into `tasks/stories/6_completed/`, carrying a short
  completion note that names the PR and links the verdict. Skip when the pull
  request implements no story.
- `tasks/reviews/pr-<N>.md` moved to `tasks/archive/reviews/pr-<N>.md`.
- Any other verdict still in `tasks/reviews/` whose pull request has since merged
  or closed. Check each with `gh pr view <N> --json state`. Do not assume.
- `CURRENT.md` brought current: the queue item struck through, the next one named.

**Why on the branch rather than after the merge.** The commit asserts a state
that is false as you write it and true the instant it lands, because the only way
it reaches the base branch is by merging. Abandon the pull request and the
assertion is abandoned with it, so there is never a window where the archive
claims something the repository does not. The alternatives are worse: filing
after the merge means a second push to the base branch, which the lockdown
forbids, or a follow-up pull request, which is the mess being removed.

**A closeout touches `tasks/` and nothing else.** That rule is what stops the
regress. A commit that cannot change reviewed behaviour does not need re-judging,
so the cycle terminates instead of judging its own bookkeeping forever. If a
closeout wants to touch source, it is not a closeout -- it is work, and it goes
back through the judge.

Report what was filed and where. Then the branch is genuinely done.

## Reporting back

Report the verdict, the blocking count, and the path to the verdict file. When a
closeout ran, name what it filed.

Do not fix what the judge found, do not stage the fixes, and do not reopen the
commit you just made. The closeout above is not an exception to this: it files
what the cycle produced, it does not answer anything the judge said. The judge is advisory. Its findings are the user's to
triage, and the whole point of a segregated reviewer is lost if the thing being
reviewed immediately rewrites itself in response.

If the judge returns blocking findings, say so plainly and stop there.
