# Cold-Start Checklist

Run these checklists on every `/cs-*` command invocation. No shortcuts.

---

## Read Checklist (run at command entry)

- [ ] Read `CONTEXT.md` in the project root -- restore project substrate
- [ ] Read `tasks/DECISIONS.md` -- restore decision history
- [ ] Read `tasks/CURRENT.md` -- restore active working state
- [ ] Confirm: "Cold start complete. Loaded N lines from M files."

### If a file is missing

- `CONTEXT.md` missing: prompt user to run `/cs-init` before continuing
- `tasks/DECISIONS.md` missing: create it from template, log that it was created
- `tasks/CURRENT.md` missing: prompt user to run `/cs-init` before continuing

---

## Write Checklist (run before command exit)

- [ ] Update `tasks/CURRENT.md`:
  - Mark completed checkboxes `[x]`
  - Update `**Next:**` to the single most concrete next action
  - Remove resolved open questions
- [ ] If a decision was made this session:
  - Append row to `tasks/DECISIONS.md`: `| YYYY-MM-DD | [decision] | [rationale] |`
- [ ] If project scope shifted (rare):
  - Update `CONTEXT.md` -- flag change for user review
- [ ] Report: files modified, lines added/removed, next action set

### Rotation check (run after writes)

- If `tasks/CURRENT.md` exceeds 100 lines: move completed items to `tasks/archive/`
- If `tasks/DECISIONS.md` exceeds 200 lines: move entries older than 30 days to `tasks/DECISIONS-archive.md`

---

## Failure Modes

- If all three files are missing: this project is not initialized. Say so and suggest `/cs-init`.
- If writes fail (permissions, disk): report the failure explicitly. Do not silently skip the write phase.
- If the user's request is unclear after cold-read: ask for clarification before doing work. Do not guess.

## Edge Cases

- **Concurrent users:** If state files show unexpected changes since last read, flag the conflict to the user before overwriting. Do not silently merge.
- **Merge conflicts:** If git reports conflicts in CURRENT.md or DECISIONS.md, present both versions and ask the user to resolve before continuing.
- **Migration from /startup:** Projects using `/startup` can adopt cold-start by running `/cs-init`. Existing `tasks/CURRENT.md` will be preserved (cs-init asks before overwriting).
