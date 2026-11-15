# Runner: OpenCode

Verified against opencode 1.18.33. Flags below were confirmed with
`opencode run --help` and `opencode agent --help`; the multi-agent loop itself has
not been run end to end on this host.

## Agents

Some skills repos' `setup.sh` renders their agents into
`~/.config/opencode/agents/<name>.md` with `mode: subagent`, the tool list, and a
`model:` only when the tier maps to one; others deploy skills and rules only.
`opencode agent list` shows what is installed. Where setup renders them, do not
create them by hand with `opencode agent create`; the next setup run is the source
of truth. With no implementer agent installed, dispatch the host's general-purpose
subagent with the full brief.

## Spawn

Two paths. In-session, the `task` tool dispatches a subagent by name: the
adapter's `Implementer agent` (default `story-implementer`) or its `Verifier`. Out of
session:

```bash
opencode run --agent "$IMPLEMENTER_AGENT" --dir "$WORKTREE" "$BRIEF"
```

`-m provider/model` overrides the model when the adapter's `Model tiers` names one
the rendered agent does not.

## Isolate

Manual, same as Codex. Create the worktree from the computed parent and pass
`--dir`:

```bash
git worktree add -b "$BRANCH" "$WORKTREE" "$REMOTE/$PARENT"
opencode run --agent "$IMPLEMENTER_AGENT" --dir "$WORKTREE" "$BRIEF"
```

Keep the worktree through verification, remediation, and the final story-state
commit, then remove it.

## Resume warm for remediation

```bash
opencode run --session <session-id> "<BLOCKERS value, verbatim>"
```

`--continue` resumes the last session, and `--fork` branches a session instead of
continuing it. Use `--session` explicitly for the same reason as on Codex.

Never use `--fork` for the verifier. A fork inherits context, and the verifier
must be cold every round.

## Structured return

```bash
opencode run --format json ...
```

Emits raw JSON events. Parse the final message; still validate against the return
template.

## Pace

Requires the loop plugin, which is not part of OpenCode itself:

```bash
opencode plugin @bybrawe/opencode-loop
```

Then `/loop 20m /story-loop`. The plugin is session-bound and idle-safe: a due
timer that fires while OpenCode is busy waits rather than interrupting. For
unattended runs after closing the terminal it ships a separate daemon.

Without the plugin, wrap `opencode run` in an external loop exactly as on Codex.
