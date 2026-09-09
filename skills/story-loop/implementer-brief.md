# Implementer Brief

The fixed artifact handed to each implementer subagent. Fill the five slots, send
it, and send nothing else. Composing this from memory every iteration is how the
parent branch goes missing.

## Template

```
You are implementing exactly one story in an isolated worktree. You have a clean
context and you will not get another one, so read what you need from the repo.

STORY:   <absolute path to the story file>
PARENT:  <parent branch, computed by the orchestrator>
REMOTE:  <remote name>
FORGE:   <forge CLI, or "none">

CONVENTIONS TO LOAD, before writing any code:
  - skills/tdd            red -> green -> refactor, and what a test worth keeping is
  - skills/git-conventions branch naming, commit format, pull request workflow
<any repo-specific skills the adapter names>

BRANCH FROM THE PARENT, NOT FROM WHAT IS CHECKED OUT:
  git fetch <REMOTE>
  git switch -c <branch> <REMOTE>/<PARENT>

Implement the story test-first. Tick acceptance criteria in the story file only
when the test that proves them passes.

OPEN THE PULL REQUEST AGAINST THE PARENT. The --base flag is required and has no
safe default:
  <FORGE> pr create --base <PARENT> ...
State the stack position in the body: the parent pull request number, or
"roots at <PARENT>" if this is the first in the chain.
If FORGE is none, stop after pushing the branch.

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
OUTCOME: landed | partial | blocked
PR: <number or ->
BRANCH: <name>
BASE: <the branch the PR was opened against>
AC: <n ticked> / <n total>
CI: green | red | absent
DEVIATIONS: <one line, or none>
FOUND: <one line of anything discovered outside scope, or none>
```

## Slot rules

| Slot | Source | Failure if wrong |
|---|---|---|
| `STORY` | The path from `"$LS" eligible` | Implementer works the wrong item |
| `PARENT` | `"$LS" parent`, never the implementer's judgement | Unstacked pull request, the failure in [chain.md](chain.md) |
| `REMOTE` | Adapter | Branches from a stale local ref |
| `FORGE` | Adapter | Attempts a pull request in a repo with no forge |
| Conventions | `skills/tdd` and `skills/git-conventions` always, plus adapter additions | Implementation lands untested |

`BASE` in the return is what the orchestrator checks against the `PARENT` it sent.
That check is the reason the return contract carries a field the implementer could
simply have gotten right.

## What must not go in the brief

The log, the chain, other stories, prior verdicts, or anything about the queue.
The implementer needs one story and one parent. Everything else is orchestrator
state, and putting it in the brief spends the clean context this design bought.
