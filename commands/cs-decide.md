---
description: "Cold-start decision mode -- present options, record choice to DECISIONS.md, update next action"
---

Load the `cold-start` skill.

## Behavior

1. **Cold read** -- Run the read checklist from `skills/cold-start/checklist.md`. Confirm load complete.

2. **Restate** -- Identify the question or decision needed from the user's request.

3. **Present options** -- Provide 2-4 options with tradeoffs (pro/con for each).

4. **Wait** -- Do not proceed until the user selects an option.

5. **Record** -- Append to `tasks/DECISIONS.md`:
   `| YYYY-MM-DD | [chosen option] | [rationale from discussion] |`

6. **Update** -- If the decision unblocks a next action, update `tasks/CURRENT.md` `**Next:**` line.

7. **Exit** -- Report the decision logged and next action set.

## Key Rule

The decision is logged to `tasks/DECISIONS.md` before any implementation begins. Decide first, then act (in a subsequent `/cs-work` session).

## Failure Mode

If canonical files are missing, stop and prompt: "Run `/cs-init` first."
