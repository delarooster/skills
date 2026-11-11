# Implementer Brief

The fixed artifact handed to each implementer subagent. Fill the slots, including
`TEAM` and `PHASE` when the adapter declares teams, send it, and send nothing else. Composing this from memory every iteration is how the
parent branch goes missing.

Dispatch to the adapter's `Implementer agent` (default `story-implementer`) when the
host has it installed: its definition carries the invariants (authorization,
scoped verification, stack policy, honest ticking) and reads the adapter itself,
so the brief only needs the slots. With `general-purpose`, send the whole template.

## Template

```
You are implementing exactly one story in an isolated worktree. You have a clean
context and you will not get another one, so read what you need from the repo.

STORY:    <absolute path to the story file>
PARENT:   <parent branch, computed by the orchestrator>
REMOTE:   <adapter Remote>
FORGE:    <adapter Forge: gh | az | none>
ADAPTER:  <absolute path to tasks/story-loop.md; read its table before any command>
SCRATCH:  <Scratch root>/<story id>/   all temp files here, never a fixed shared path
TEAM:     <team name; omit the line when the adapter declares no teams>
PHASE:    <full | 1; omit the line for full>

CONVENTIONS TO LOAD, before writing any code:
  - the tdd skill             red -> green -> refactor, and what a test worth keeping is
  - the git-conventions skill branch naming, commit format, pull request workflow
<any repo-specific skills the adapter names>

BRANCH FROM THE PARENT, NOT FROM WHAT IS CHECKED OUT, and only inside your own
isolated worktree, never the shared checkout:
  git fetch <REMOTE>
  git switch -c <branch> <REMOTE>/<PARENT>
If your branch already exists on <REMOTE>, switch to it and continue it instead.

<PHASE wording, verbatim: see Phase wording below>

Implement the story test-first. Tick acceptance criteria in the story file only
when the test that proves them passes.
For each testable behavior, follow the tdd skill: commit each failing test before
the code that makes it pass, so the branch shows red then green.
Documentation-only changes name their relevant validation instead of inventing a failing runtime test.
Use the adapter's commands for each path
the story touches (`loop-state.sh command <ADAPTER> <column> <path>`), within its
Stack policy; never tear a shared stack down destructively.

OPEN THE PULL REQUEST AGAINST THE PARENT. The base argument is required and has
no safe default. Open it as a draft only if it really is a draft:
  <CREATE>
State the stack position in the body: the parent pull request number, or
"roots at <PARENT>" if this is the first in the chain. Name any file you touched
that the parent chain already touched. If the story's Categories include a
human-only category, say so on the first line of the body.
If FORGE is none, stop after pushing the branch.
The orchestrator owns native stack linking after your return; do not run gh stack link.

VERIFY BEFORE YOU OPEN IT, SCOPED. Where you work, run only the narrowest checks
that prove what you changed: the test files and filters for the story's criteria,
lint and type checks limited to touched files. Full suites, full builds and
end-to-end runs go to the adapter's `Full runs at` (CI by default) or wherever the
repo's AGENTS.md sends them, never the machine you were spawned on unless one of
those names it. If per-change CI skips the proof the story needs (`E2E in PR CI:
no`), dispatch the adapter's `Narrowed e2e` once. State in the body what you ran,
where, and what it reported -- counts, and what skipped, not adjectives. Claiming
a run you did not do is the one unrecoverable dishonesty here.

Do not wait on CI: return once the pull request is open, with CI: pending unless
the checks have already reported. The orchestrator waits and messages you if they
go red. Do not merge your pull request. Do not touch any branch but your own.

SPEND FEW TURNS. Every tool call re-sends your whole context. Batch independent
reads and commands into one call, read slices rather than whole files, find code
with grep before opening it, and do not re-read a file you just edited.

YOU ARE AUTHORIZED TO: create your branch, commit, push that branch, open the
pull request, move the story file between state folders on your branch, and make
the closeout commit when the orchestrator sends it.
YOU MAY merge <PARENT> into your own branch to freshen it. Never rebase.
YOU ARE NOT AUTHORIZED TO: merge into any branch but your own, force push, rebase,
reset, amend, tag, delete branches, push to <PARENT> or to main/master/develop, change git config, bypass
hooks, or edit tasks/ outside your story file, except for the closeout below.
If you need another exception, return OUTCOME: blocked with the reason.

CLOSEOUT EXCEPTION: With Closeout by: implementer, a clean verdict and an
explicit closeout message authorize moving your story to 6_completed, copying
the verdict file at the path the message names into the adapter's Verdict archive
(deleting that file when the archive is none), and updating only the named per-story state files.
Make and push that tasks-only commit on your story branch only. Do not edit the
verdict's contents. No other tasks edits are authorized.

RETURN EXACTLY THIS AND NOTHING ELSE. No diff, no summary, no commentary:

STORY: <id>
OUTCOME: landed | partial | blocked | phase1
PR: <number or ->
BRANCH: <name>
BASE: <the branch the PR was opened against>
AC: <n ticked> / <n total>
CI: green | red | absent | pending
STACK: up | down | none
DEVIATIONS: <one line, or none>
FOUND: <one line of anything discovered outside scope, or none>
```

## Phase wording

With teams, the `PHASE` line takes its text from [teams.md](teams.md#phase-wording).
Without teams it is always `PHASE FULL. Do the whole story as written in this brief.`

## The CREATE slot

The orchestrator renders it from the forge verb table in [chain.md](chain.md),
with `<PARENT>` already substituted, so the implementer never picks a forge
syntax or a base:

| FORGE | CREATE |
|---|---|
| `gh` | `gh pr create --base <PARENT> --head <branch> --title "<title>" --body-file <SCRATCH>body.md` |
| `az` | `az repos pr create --source-branch <branch> --target-branch <PARENT> --title "<title>" --description "$(cat <SCRATCH>body.md)"` |
| `none` | `none: push the branch and stop` |

## Slot rules

| Slot | Source | Failure if wrong |
|---|---|---|
| `STORY` | The path from `"$LS" eligible` | Implementer works the wrong item |
| `PARENT` | `"$LS" parent`, never the implementer's judgement | Unstacked pull request, the failure in [chain.md](chain.md) |
| `REMOTE` | Adapter | Branches from a stale local ref |
| `FORGE`, `CREATE` | Adapter plus the verb table | A pull request in a repo with no forge, or against the default branch |
| `ADAPTER` | The governing adapter; in a workspace queue, the target repo's | Wrong commands, wrong stack policy |
| `SCRATCH` | `"$LS" adapter-path <file> 'Scratch root'` plus the story id | Parallel implementers overwrite each other's temp files |
| `TEAM` | The team whose `eligible --team` produced the story | Story logged against the wrong team's blocked count |
| `PHASE` | `1` when lanes < teams, else `full` | Two implementers share one runtime and corrupt each other's evidence |
| Conventions | The `tdd` and `git-conventions` skills always, plus adapter additions | Implementation lands untested |

`BASE` in the return is what the orchestrator checks against the `PARENT` it sent.
That check is the reason the return contract carries a field the implementer could
simply have gotten right. `CI: pending` sends the orchestrator to wait on checks
before verifying ([orchestrator.md](orchestrator.md#implementer-subagent)).

## What must not go in the brief

The log, the chain, other stories, prior verdicts, or anything about the queue.
The implementer needs one story and one parent. Everything else is orchestrator
state, and putting it in the brief spends the clean context this design bought.
Nor repo policy prose: a rule the implementer must follow belongs in its agent
definition or an adapter field, where it survives the session.
