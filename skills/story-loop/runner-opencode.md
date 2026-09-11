# Runner: OpenCode

Verified against opencode 1.18.29. Flags below were confirmed with
`opencode run --help` and `opencode agent --help`; the multi-agent loop itself has
not been run end to end on this host.

## Spawn

Two paths. In-session, the `task` tool dispatches a subagent. Out of session:

```bash
opencode run --agent <agent-name> --dir "$WORKTREE" "$BRIEF"
```

`opencode agent list` shows what is available; `opencode agent create` adds one.
A repo that declares a verifier agent registers it here.

## Isolate

Manual, same as Codex. Create the worktree from the computed parent and pass
`--dir`:

```bash
git worktree add -b "$BRANCH" "$WORKTREE" "$REMOTE/$PARENT"
opencode run --dir "$WORKTREE" "$BRIEF"
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
