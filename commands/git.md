---
description: Full git push cycle — verify feature branch, commit staged changes with a meaningful message, push, open a PR if one doesn't exist, and dispatch an independent judge if the repo has one
---

Ensure we're on a feature branch, if not create one, and then make a meaningful
commit, push to the remote, and if there's not a current pr, open one.

## Then: judge the PR, if this repo has a judge

Invoking `/git` is the explicit authorization for the commit and push above.
It is **not** authorization to act on anything the judge finds.

**Guard.** Only do this when `.claude/agents/pr-judge.md` exists in the repo.
Most repos have no judge; skip the whole section silently there. Do not offer to
create one.

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

## Reporting back

Report the verdict, the blocking count, and the path to the verdict file.

Do not fix what the judge found, do not stage the fixes, and do not reopen the
commit you just made. The judge is advisory. Its findings are the user's to
triage, and the whole point of a segregated reviewer is lost if the thing being
reviewed immediately rewrites itself in response.

If the judge returns blocking findings, say so plainly and stop there.
