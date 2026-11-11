# Chain and Stacking

## The failure this file exists to prevent

An implementer with a clean context cannot know what the previous story built.
Asked to open a pull request, it targets the repository default, because that is
the only base it can see, and a long unattended run produces several such pull
requests before anyone notices.

Reminding the implementer works once. Handing it the parent works every time.
Stacking is orchestrator state, and the orchestrator is the only participant that
holds it.

## Why unstacked is wrong, not just untidy

Under `Merge policy: never` nothing merges during a run, and even under
`clean-verdict` a parent is usually still open when its child starts. A pull
request rooted at the base branch therefore contains no prior story's work. For any story that builds on earlier work:

- the branch cannot compile against work it needs
- the diff shows changes the story does not own
- the conflict surfaces at merge time, long after the context that could fix it

`scripts/e2e-chain.sh` reproduces both outcomes side by side. In the correct run
`git merge-base --is-ancestor` confirms each branch contains its predecessor and
the tip carries all three files. In the control run, branched from base each time,
the same check fails and the tip carries one file.

## Chain head

Derived from the log, never from the git host:

```bash
"$LS" head <log> <base>
```

The branch on the last row whose outcome is `landed` or `partial` **and** whose
branch is not `-`. A `blocked` row does not advance the head, so a chain never
roots on a branch that failed. An empty log yields the base branch.

Because it derives from the log alone, it survives a cold start. Kill the session
mid-queue, re-invoke, and the next story still stacks on the real head. That is
also why a row is appended even when a story is blocked: the log is the chain.

## Parent computation

```bash
"$LS" parent <log> <base> <mode> <deps>
```

| Story declares | mode | Parent |
|---|---|---|
| `Dependencies: <ids>` | `linear` | The chain head, which already holds every landed dependency |
| `Dependencies: <ids>` | `dag` | Branch logged for the last-landed of those ids |
| `Dependencies: None` | `linear` | The chain head |
| `Dependencies: None` | `dag` | The declared base branch |
| A dependency not landed | any | Not eligible. Never silently root at base |

**A merged parent is the base.** When the computed parent's pull request has merged
into the base branch, supply the base branch as `PARENT`: its work is already
there, and the branch is usually deleted on merge. Confirm the merge with the
forge's "list merged by head" verb below, not from a missing ref alone, and say
"parent merged, rooted at <base>" in the log row. An unmerged parent that has
vanished is still a stop.

`linear` is the default. `dag` is honest about what actually depends on what, but
it is only safe when `Dependencies` headers are trustworthy across the whole
queue: two base-rooted stories touching the same files conflict, and nothing
merges to resolve them. Linear degrades gracefully when headers are wrong; dag
produces silent conflicts.

## The two writes that carry it

Both must be explicit in the implementer brief, and the template in
[implementer-brief.md](implementer-brief.md) already carries them:

```bash
git fetch <remote> && git switch -c <story-branch> <remote>/<parent>
<the forge's "create PR with base" verb, base = <parent>>
```

**The second is the one that gets missed.** A correctly branched story with a
defaulted pull request base still produces an unstacked pull request, and it looks
completely fine locally. Every forge defaults the target to the repository
default; the base argument is not optional and is not a default.

With `forge: none` there is no second write; the chain is the branches alone, and
that is a valid mode.

## Forge verbs

The only forge commands the loop and its agents use. `<n>` is the pull request
number or id, `<branch>` a head branch, `<parent>` the computed parent.

| Verb | `gh` | `az` (`az repos`) | `none` |
|---|---|---|---|
| Create PR with base | `gh pr create --base <parent> --head <branch> --title <t> --body-file <f>` | `az repos pr create --source-branch <branch> --target-branch <parent> --title <t> --description "$(cat <f>)"` | push the branch only |
| List merged by head | `gh pr list --state merged --head <branch> --json number -q '.[].number'` | `az repos pr list --source-branch <branch> --status completed --query "[].pullRequestId" -o tsv` | `git merge-base --is-ancestor <remote>/<branch> <remote>/<base>` |
| Merge (merge commit) | `gh pr merge <n> --merge` | `az repos pr update --id <n> --status completed --squash false` | not available; merge policy is `never` |
| Check status | `gh pr view <n> --json state,isDraft,baseRefName,headRefOid` | `az repos pr show --id <n> --query "{status:status,draft:isDraft,target:targetRefName,source:lastMergeSourceCommit.commitId}"` | `git rev-parse <remote>/<branch>` |
| Get checks | `gh pr checks <n>` (exit 8 while pending) | `az repos pr policy list --id <n> --query "[].{name:configuration.type.displayName,status:status}" -o table` | none; `CI: absent` |

`az` notes, marked where not yet run against a live organization:

- Each `az` verb needs `--org` and `--project` unless `az devops configure -d`
  set them or `--detect true` resolves them from the git remote. **VERIFY** that
  detection works from a worktree.
- `--source-branch` on `list`: **VERIFY** whether a bare branch name matches or
  `refs/heads/<branch>` is required.
- Merge: `--squash false` asks for a merge commit, but a branch policy that forces
  squash or rebase wins. **VERIFY** the completed merge type; ADO may also refuse
  completion while required policies are pending, which is correct.
- Neither forge's merge verb deletes the source branch unless asked; do not ask.
  Branch deletion stays outside the loop's grant.

Checks and CI system are separate: `gh pr checks` reports GitHub Actions and any
other status source; `az repos pr policy list` reports build validation policies,
which is how Azure Pipelines results reach a pull request.

## Declaration

Branch stacking and GitHub's native stack UI are distinct. Native linking applies
only to sequential linear children, not roots, DAG or teams; the orchestrator
follows [native-stacks.md](native-stacks.md). Skipping native linking never changes
the computed parent or weakens `check-base`.

The pull request body states its stack position: the parent pull request number,
or `roots at <base>` for the first in a chain. This surfaces a mistake in review
rather than at merge time.

## Verification without reading a diff

The implementer returns `BASE`. Compare it to the parent you supplied:

```bash
"$LS" check-base <expected-parent> <returned-base>
```

Non-zero means log `blocked :: unstacked`. This is the one claim in the return
contract the orchestrator can check entirely on its own, so it is checked every
iteration rather than trusted.

## Remediation does not force a restack

In sequential mode the parent is final before the child branches, because the next
story is not selected until the previous one has logged. Parallel fan-out breaks
that property and would need a restack pass whenever a parent changes after a
child has branched. That is the strongest argument for staying sequential. Teams
avoid the restack without giving up dependencies: a story without one roots at the
base, and a story with one, in any team, stacks on its dependency only after that
dependency's row is written, which happens after its merge or final routing. The
parent is final before the child branches, as in sequential mode. See [teams.md](teams.md).

## Depth

```bash
"$LS" depth <log> <base>
```

Counts only rows that actually landed work and have not merged. Exceeding the adapter's soft cap logs
a note and continues; `Stack depth cap: none` drops the note, never the count.
A deep chain means stories should have been merged: under `never` that call
belongs to the operator, under `clean-verdict` the loop is already making it.

The risk at depth is not the number. It is two stories editing one file with
nothing merged to resolve them. An implementer names any file its story touches
that an ancestor in the chain already touched (`git diff --name-only
<remote>/<base>...<remote>/<parent>`), in the pull request body; the orchestrator
carries that into the log row. The signal costs nothing and is what a human needs
to decide what to land first.
