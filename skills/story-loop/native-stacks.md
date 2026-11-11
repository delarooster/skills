# Native GitHub Stacks

The orchestrator alone links PRs, at step 5 after checking the returned base.
Implementers never link, so a return and its backstop cannot race. The gate is:

```bash
"$LS" native-stack <forge> <mode> <teams:yes|no> <parent> <base> <Native stacks: auto|off>
```

`teams` is `yes` whenever the adapter declares a Teams table, even for one team.
Resolve merged parents to the base first, as chain.md requires. `skip :: ...` is
success: roots have no parent PR yet, DAG siblings and teams retain independent
branch chains, other forges have no GitHub native stack, `off` is the adapter's
opt-out, and `no gh stack` means the extension is not installed. Every skip leaves
the chain on git branches alone, which is complete without native stacks. Do not manufacture a
parent PR or append those branches to a shared native chain.

## Discover before writing

On `link`, use the target repository's forge context, never a workspace sibling:

1. Read the child with `gh pr view <PR> --json number,url,state,baseRefName,headRefName`.
   It must be open and its base must equal the computed parent.
2. Find the parent's open PR with `gh pr list --state open --head <parent> --limit 100
   --json number,url,headRefName,baseRefName`. Require exactly one matching head in
   this repository. A missing or ambiguous parent is a stop, not a root fallback.
3. Read both memberships with `gh api 'repos/{owner}/{repo}/stacks?pull_request=<N>'`,
   once for the parent PR and once for the child. The response is an array of
   stacks; `.number` is the stack number, `.base.ref` its base, and
   `.pull_requests` is ordered bottom to top with `.number` and `.head.ref` per PR.
   Failed API access, including stacks not enabled, is never read as an empty array:
   skip linking, add `native stack skipped :: <error>` to the log row's Notes, and
   continue on git branches.
4. No membership may be ambiguous. An existing stack must be open and have the
   adapter's base. If the child is already immediately after its parent in the same
   stack with the correct PR base, linking is already complete: no write is needed.
   Otherwise the child must have no membership, and an existing parent stack must
   have that parent at its top. A child in another stack or a non-top parent is a
   stop; never repair it by retargeting PRs, reordering, or unstacking others.

## Link once, then verify

Use the installed `github/gh-stack` extension; the gate already checked
`gh stack link --help`. Never install it from an unattended loop. Pass PR URLs, not branch names, so linking cannot push or
create additional branches/PRs. Never pass `--open`.

- **No parent stack:** require the parent's own PR base to equal the adapter's
  base. Run `gh stack link --base <base> <parent-PR-URL> <child-PR-URL>`. A parent
  with unlinked ancestors needs operator reconciliation rather than a partial stack.
- **Existing parent stack:** run `gh stack link <stack-number> <child-PR-URL>`.
  Do not use just the parent PR number: growing an existing stack that way can
  omit earlier members. The stack number is discovered above, never guessed or
  carried as stale session state.

Re-read the child base and both memberships after the command. Require the same
computed base and the child immediately after its parent in the same stack. A
successful exit alone is insufficient: the extension can warn about base updates.
If the link command fails because the extension or the stacks API is unavailable,
nothing was linked: note `native stack skipped :: <error>` in the log row and
continue on git branches. If verification disagrees after a link took effect,
preserve the PR, log `blocked :: native stack` with the error, and stop before the
verifier, merge or next dispatch. Do not undo a partially successful operation. On
resume, repeat discovery; the already-linked case makes retry safe.

Native stacks are optional display on top of the git chain, never a reason to
change branch topology.
