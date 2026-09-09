# Chain and Stacking

## The failure this file exists to prevent

An implementer with a clean context cannot know what the previous story built.
Asked to open a pull request, it targets the repository default, because that is
the only base it can see. An observed 20-story run produced six such pull requests
before the operator noticed and said so.

Reminding the implementer works once. Handing it the parent works every time.
Stacking is orchestrator state, and the orchestrator is the only participant that
holds it.

## Why unstacked is wrong, not just untidy

Nothing merges during a run. A pull request rooted at the base branch therefore
contains no prior story's work. For any story that builds on earlier work:

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
| `Dependencies: <ids>` | any | Branch logged for the last-landed of those ids |
| `Dependencies: None` | `linear` | The chain head |
| `Dependencies: None` | `dag` | The declared base branch |
| A dependency not landed | any | Not eligible. Never silently root at base |

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
<forge-cli> pr create --base <parent> ...
```

**The second is the one that gets missed.** A correctly branched story with a
defaulted pull request base still produces an unstacked pull request, and it looks
completely fine locally. Passing `--base` is not optional and is not a default.

With `forge: none` there is no second write; the chain is the branches alone, and
that is a valid mode.

## Declaration

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
child has branched. That is the strongest argument for staying sequential.

## Depth

```bash
"$LS" depth <log> <base>
```

Counts only rows that actually landed work. Exceeding the adapter's soft cap logs
a note and continues. A deep chain means stories should have been merged, and that
call belongs to the operator, not to the loop.
