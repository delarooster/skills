---
description: "Initialize a project for cold-start workflow -- creates CONTEXT.md, tasks/CURRENT.md, and tasks/DECISIONS.md from templates"
---

Load the `cold-start` skill.

## Behavior

1. Check if `CONTEXT.md`, `tasks/CURRENT.md`, or `tasks/DECISIONS.md` already exist. If any do, ask the user before overwriting.

2. Create `tasks/` directory if it does not exist.

3. Ask the user:
   - "What is this project? (1-2 sentences)" -- use the answer for CONTEXT.md Goal section.
   - "What are the key constraints?" -- use for Constraints section.
   - "What is the immediate next action?" -- use for CURRENT.md `**Next:**` line.

4. Create the three files from the templates in `skills/cold-start/templates/`:
   - `CONTEXT.md` -- fill in Goal and Constraints from user answers
   - `tasks/CURRENT.md` -- fill in Next action, leave checkboxes as placeholders
   - `tasks/DECISIONS.md` -- create with header only (no entries yet)

5. Confirm: "Cold-start initialized. 3 files created. Use `/cs-work` for the next session."

## Notes

- Idempotent: will not clobber existing files without explicit confirmation.
- This command writes files and exits. It does not begin work.
