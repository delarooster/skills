# Teams and Lanes

Read only when the adapter declares a `Teams` table; without one, nothing here
applies and the rest of the skill holds unchanged. A team is a lane of the queue: its own
ordered stories, one in flight at a time, so independent surfaces progress in
parallel without sharing a chain.

| Concern | Rule |
|---|---|
| Dispatch | One story in flight per team. On start, on resume and on every wake, dispatch every idle team's head, `"$LS" eligible <queue-root> <log> --team <name> <adapter>`, at once, up to `Phase-1 cap` implementers working without a lane |
| Phases | Lanes >= teams: every brief is `PHASE: full`, no lock. Lanes < teams: every brief is `PHASE: 1`, which touches no shared runtime and returns `OUTCOME: phase1` |
| Granting a lane | Append `wait` to the lock on each `phase1` return. While a lane is free, promote the oldest `wait` to `held` with a lane number and send that implementer the phase-2 text below |
| Release | Remove the `held` line only after the story's merge, or its final routing when the loop does not merge, **and** a return reporting `STACK: down` or `none`. Remediation may need the runtime, and the next holder should test against a base that already has this story |
| Log | `phase1` writes no row. As without teams, the story's one row is written last, after its merge or final routing, so `eligible` and `head` see exactly what they see without teams |
| Parent | `"$LS" parent <log> <base> dag <deps>`: no-dependency stories branch from the declared base, never from another team's head. A story with a dependency stacks on that dependency's branch, across teams too. That never needs a restack: the dependency is done only once its row exists, and its row is written after its merge or final routing, so its branch is final before the child branches. A merged dependency resolves to the base ([chain.md](chain.md)). Merge-as-you-go: when a story's parent has moved, its implementer merges the parent into the story branch (the base, for a root), never rebases |
| Merges | Only under `Merge policy: clean-verdict` ([verify.md](verify.md#merge)). The orchestrator serializes them, one at a time, oldest clean verdict first, re-checking each branch is not behind the base before merging |
| Throughput | Never idle on one story while another team has eligible work. Verifiers, remediation and closeouts run while other teams' implementers work; waiting on any of them is a reason to dispatch, not to sleep |
| Blocked count | Two consecutive `blocked` rows stop **that team**, not the loop. A team with nothing eligible idles until a dependency lands |
| Loop-wide stops | Escalation, evidence holds, a MERGE AFTER FIXES left after should-fix remediation (or with it `off`) when the adapter names no `Review list`, exhausted remediation and the authorization boundary stop new dispatch in every team. In-flight implementers finish their current phase and log; nothing new starts |

The lock file has one format, the adapter's `Stack lock format`. A repo whose own
checklists already read a lock file declares that file's line format there, with a
placeholder for each value below, and the orchestrator writes that format and no
other. The default, `loop`, is one line per lane holder or waiter, tab-separated:

```
held	<id>	<team>	<lane>	<utc>
wait	<id>	<team>	-	<utc>
```

Whatever the format, it must say which story holds which lane and which wait, oldest
first. An empty or missing file means every lane is free.

**Resume.** A fresh session reconstructs state without asking, from the log, the state
folders, the lock file and the remote's story branches, first match wins:

| Source | Says |
|---|---|
| Log row for the id | Finished: merged or finally routed. Release any lock line it still holds |
| Open pull request for the story branch, no row | The implementer finished. Verify, then move the story, close out and merge per the policy, then write the row. Do this whatever folder the story file is in: after a crash it may still sit in `1_backlog`, `2_ready` or `3_in-progress`, because the move happens late and on the branch |
| `held` line, no pull request | Phase 2 was granted. Re-dispatch phase 2 cold on the existing branch, same lane |
| `wait` line, no row | Phase 1 finished. Keep its place in the line |
| Story branch on the remote, no row, no lock line | Implementer interrupted. Re-dispatch cold with its phase, `full` when lanes >= teams, else `1`; the brief continues the existing branch |
| None of these | Not started. The team's head as usual |

Story branches are found by name on the remote (`git ls-remote --heads`), which
reads no content. A `held` line whose story has a row is a stale grant: release it,
then dispatch.

## Phase wording

Paste the row for the phase. Phase 2 is never a fresh brief: it is a message to the
same implementer, warm, when the orchestrator grants a lane. A cold phase 2, after a
crash, gets the full brief with the phase-2 text in place of the phase line.

| Phase | Exact text |
|---|---|
| `full` | `PHASE FULL. Do the whole story as written in this brief.` |
| `1` | `PHASE 1. You do not hold a stack lane. Do not start, stop, reset or connect to any shared runtime: no stack, no shared database, no end-to-end run. Implement test-first using only tests that need none of them, then commit and push your branch. Do not open the pull request. Return OUTCOME: phase1 with STACK: none, PR: - and CI: absent, then wait: phase 2 arrives as a message.` |
| `2` | `PHASE 2. You now hold stack lane <n>, recorded in <lock path>. If <PARENT> has moved since you branched, merge it into your branch; never rebase. That is the only merge you may make. Run the shared-runtime verification, open the pull request, do not wait on CI (return CI: pending unless the checks have already reported; the orchestrator waits), tear your runtime down, and return the full contract with STACK: down.` |

`STACK: up` on any return means a runtime was left running. The orchestrator does not
release the lane until a later return reports `down` or `none`.
