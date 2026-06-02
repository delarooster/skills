---
description: "Cold-start work session -- read state, execute, write state, exit. Stateless by design."
---

Load the `cold-start` skill.

## Behavior

1. **Cold read** -- Run the read checklist from `skills/cold-start/checklist.md`. Confirm load complete.

2. **Acknowledge** -- Restate the user's request from the current invocation. Make no assumptions about prior conversation. The only context is what was read from files.

3. **Execute** -- Do the work requested.

4. **Cold write** -- Run the write checklist from `skills/cold-start/checklist.md`.

5. **Report** -- State files modified, lines changed, next action set. Exit.

## Failure Mode

If any of the three canonical files is missing, stop and prompt: "Missing [file]. Run `/cs-init` to bootstrap this project."
