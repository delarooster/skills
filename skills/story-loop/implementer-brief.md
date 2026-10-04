# Implementer Brief

The fixed artifact handed to each implementer subagent. Fill the five slots, plus
`TEAM` and `PHASE` when the adapter declares teams, send it, and send nothing else. Composing this from memory every iteration is how the
parent branch goes missing.

## Template

```
You are implementing exactly one story in an isolated worktree. You have a clean
context and you will not get another one, so read what you need from the repo.

STORY:   <absolute path to the story file>
PARENT:  <parent branch, computed by the orchestrator>
REMOTE:  <remote name>
FORGE:   <forge CLI, or "none">
TEAM:    <team name; omit the line when the adapter declares no teams>
PHASE:   <full | 1; omit the line for full>

CONVENTIONS TO LOAD, before writing any code:
  - skills/tdd            red -> green -> refactor, and what a test worth keeping is
  - skills/git-conventions branch naming, commit format, pull request workflow
<any repo-specific skills the adapter names>

BRANCH FROM THE PARENT, NOT FROM WHAT IS CHECKED OUT:
  git fetch <REMOTE>
  git switch -c <branch> <REMOTE>/<PARENT>
If your branch already exists on <REMOTE>, switch to it and continue it instead.

<PHASE wording from the table below, verbatim>

Implement the story test-first. Tick acceptance criteria in the story file only
when the test that proves them passes.

OPEN THE PULL REQUEST AGAINST THE PARENT. The --base flag is required and has no
safe default. Open it as a draft only if the repo's own rules say drafts change
what CI runs; otherwise open it normally:
  <FORGE> pr create --base <PARENT> ...
State the stack position in the body: the parent pull request number, or
"roots at <PARENT>" if this is the first in the chain.
If FORGE is none, stop after pushing the branch.

VERIFY LOCALLY BEFORE YOU OPEN IT, and state in the body what you ran and what it
reported -- counts, not adjectives. Per-PR CI commonly skips integration, so that
proof is yours to produce and nothing downstream reproduces it. Claiming a run you
did not do is the one unrecoverable dishonesty here.

Wait until CI leaves a pending state, or roughly four minutes, then stop. Do not
merge. Do not touch any branch but your own.

YOU ARE AUTHORIZED TO: create your branch, commit, push that branch, open the
pull request, and move the story file between state folders.
YOU ARE NOT AUTHORIZED TO: merge, force push, rebase, reset, amend, tag, delete
branches, push to <PARENT> or to main/master/develop, change git config, or
bypass hooks. If you believe you need one of these, return OUTCOME: blocked with
the reason instead of doing it.

RETURN EXACTLY THIS AND NOTHING ELSE. No diff, no summary, no commentary:

STORY: <id>
OUTCOME: landed | partial | blocked | phase1
PR: <number or ->
BRANCH: <name>
BASE: <the branch the PR was opened against>
AC: <n ticked> / <n total>
CI: green | red | absent
STACK: up | down | none
DEVIATIONS: <one line, or none>
FOUND: <one line of anything discovered outside scope, or none>
```

## Phase wording

Paste the row for the phase. Phase 2 is never a fresh brief: it is a message to the
same implementer, warm, when the orchestrator grants a lane. A cold phase 2, after a
crash, gets the full brief with the phase-2 text in place of the phase line.

| Phase | Exact text |
|---|---|
| `full` | `PHASE FULL. Do the whole story as written in this brief.` |
| `1` | `PHASE 1. You do not hold a stack lane. Do not start, stop, reset or connect to any shared runtime: no stack, no shared database, no end-to-end run. Implement test-first using only tests that need none of them, then commit and push your branch. Do not open the pull request. Return OUTCOME: phase1 with STACK: none, PR: - and CI: absent, then wait: phase 2 arrives as a message.` |
| `2` | `PHASE 2. You now hold stack lane <n>, recorded in <lock path>. If <PARENT> has moved since you branched, merge it into your branch; never rebase. That is the only merge you may make. Run the shared-runtime verification, open the pull request, wait on CI as above, tear your runtime down, and return the full contract with STACK: down.` |

`STACK: up` on any return means a runtime was left running. The orchestrator does not
release the lane until a later return reports `down` or `none`.

## Slot rules

| Slot | Source | Failure if wrong |
|---|---|---|
| `STORY` | The path from `"$LS" eligible` | Implementer works the wrong item |
| `PARENT` | `"$LS" parent`, never the implementer's judgement | Unstacked pull request, the failure in [chain.md](chain.md) |
| `REMOTE` | Adapter | Branches from a stale local ref |
| `FORGE` | Adapter | Attempts a pull request in a repo with no forge |
| `TEAM` | The team whose `eligible --team` produced the story | Story logged against the wrong team's blocked count |
| `PHASE` | `1` when lanes < teams, else `full` | Two implementers share one runtime and corrupt each other's evidence |
| Conventions | `skills/tdd` and `skills/git-conventions` always, plus adapter additions | Implementation lands untested |

`BASE` in the return is what the orchestrator checks against the `PARENT` it sent.
That check is the reason the return contract carries a field the implementer could
simply have gotten right.

## What must not go in the brief

The log, the chain, other stories, prior verdicts, or anything about the queue.
The implementer needs one story and one parent. Everything else is orchestrator
state, and putting it in the brief spends the clean context this design bought.
