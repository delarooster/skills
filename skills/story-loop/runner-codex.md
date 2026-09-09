# Runner: Codex

Verified against codex-cli 0.149.0. Subcommands and flags below were confirmed
with `codex exec --help`; the multi-agent loop itself has not been run end to end
on this host.

## Spawn

No native subagent tool. A subagent is a child process, which is a clean context
by construction:

```bash
codex exec --cd "$WORKTREE" "$BRIEF"
```

Read the brief from a file or stdin rather than inlining a long prompt. `codex
exec -` takes instructions on stdin.

## Isolate

Manual. Create the worktree yourself, from the computed parent, and hand the path
to `--cd`:

```bash
git worktree add -b "$BRANCH" "$WORKTREE" "$REMOTE/$PARENT"
codex exec --cd "$WORKTREE" "$BRIEF"
git worktree remove "$WORKTREE"
```

Removal is the orchestrator's job. A crashed child leaves the worktree behind, and
`git worktree prune` is the recovery.

## Resume warm for remediation

```bash
codex exec resume <session-id> "<blocking findings, verbatim>"
```

`codex exec resume --last` also works when only one child is in flight, which is
the sequential case. Prefer the explicit id anyway: it survives an interleaved
verifier run.

## Structured return

`--json` emits raw events. Parse the final message rather than scraping formatted
output, and still validate against the return template.

## Pace

No scheduler. Wrap it externally:

```bash
while :; do codex exec "/story-loop"; sleep 1200; done
```

`launchd` or `cron` work equally well for unattended runs. There is no in-session
equivalent of the other two hosts' `/loop`.

## Note on delivery

`setup.sh` deploys skills to `~/.agents/skills` for Codex and does **not** deploy
commands. This skill is therefore reachable on Codex; a command-only version would
not have been.
