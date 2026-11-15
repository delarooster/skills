# Runner: Codex

Verified against codex-cli 0.157.1. Subcommands and flags below were confirmed
with `codex exec --help`; the multi-agent loop itself has not been run end to end
on this host.

## Agents

Some skills repos' `setup.sh` renders their agents into
`~/.codex/agents/<name>.toml`, with the body as `developer_instructions` and the
tier as `model_reasoning_effort`; others deploy skills and rules only. Check
`~/.codex/agents/` rather than assume. Codex's multi-agent feature (`codex features
list` shows `multi_agent`) makes installed agents available as agent types to its
in-session spawn tool. With no implementer agent installed, use a child process with
the full generic template, below.

## Spawn

In session, spawn the agent type by name with the brief as its message; the
implementer's name is the adapter's `Implementer agent` (default
`story-implementer`). The
loop needs only those two arguments; their exact names on the spawn tool are
listed under "Not yet verified" below. Do not spawn the verifier as a full-history
fork: a fork inherits the parent's context and agent type, and the verifier must
be cold.

Out of session, a subagent is a child process, which is a clean context by
construction:

```bash
codex exec --cd "$WORKTREE" - < "$BRIEF_FILE"
```

`codex exec -` takes instructions on stdin. A child process does not load an agent
TOML as its role, so send the agent's body ahead of the brief, or the full
generic template from [implementer-brief.md](implementer-brief.md).

## Sandbox

`workspace-write` allows writes only inside the working root (plus temp) and
turns network access off. Two agents need more:

| Agent | Needs | Why |
|---|---|---|
| The verifier | write `Verdict dir` when it is outside the repo; network for the forge's read verbs | its only output is the verdict file |
| The implementer | network for `git fetch`, `git push` and the forge's create verb | it opens the pull request |

Keep `workspace-write` and widen it, rather than dropping to
`danger-full-access`:

```bash
codex exec --cd "$WORKTREE" --sandbox workspace-write \
  --add-dir "$VERDICT_DIR" \
  -c sandbox_workspace_write.network_access=true - < "$BRIEF_FILE"
```

`--add-dir` makes the verdict directory writable; the `-c` override enables
network inside the sandbox. An agent that only pushes or opens a pull request needs
network alone, and a read-only agent needs neither.
`danger-full-access` also works, and is the fallback if an agent file cannot carry
the widened settings; it removes the sandbox entirely, so reserve it for a host the
operator already trusts with unattended pushes.

## Isolate

Manual. Create the worktree yourself, from the computed parent, and hand the path
to `--cd`:

```bash
git worktree add -b "$BRANCH" "$WORKTREE" "$REMOTE/$PARENT"
codex exec --cd "$WORKTREE" "$BRIEF"
```

Keep the worktree through verification, remediation, and the final story-state
commit, then remove it. Removal is the orchestrator's job. A crashed child leaves
the worktree behind, and `git worktree prune` is the recovery.

## Resume warm for remediation

```bash
codex exec resume <session-id> "<BLOCKERS value, verbatim>"
```

`codex exec resume --last` also works when only one child is in flight, which is
the sequential case. Prefer the explicit id anyway: it survives an interleaved
verifier run.

## Structured return

`--json` emits raw events. Parse the final message rather than scraping formatted
output, and still validate against the return template. `--output-schema <file>`
constrains the final message to a JSON schema; it is the closest thing to enforced
return shape on any of the three hosts.

## Pace

No scheduler. Wrap it externally:

```bash
while :; do codex exec "/story-loop"; sleep 1200; done
```

`launchd` or `cron` work equally well for unattended runs. There is no in-session
equivalent of the other two hosts' `/loop`.

## Not yet verified

- The in-session spawn tool's argument names for "agent type" and "message".
- Whether a newer `codex exec` accepts an agent selector, so a child process could
  load an agent TOML as its role.
- Whether an agent TOML in `~/.codex/agents/` honours `[sandbox_workspace_write]`
  keys (`network_access`, `writable_roots`) the way `config.toml` does.

## Note on delivery

A skills repo's `setup.sh` typically deploys skills to `~/.agents/skills` for Codex,
and agents to `~/.codex/agents/` only where it renders them. Commands are not deployed, which Codex has deprecated; this skill is
reachable because it is a skill.
