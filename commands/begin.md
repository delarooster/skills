---
description: Kick off a work session — read scratchpad notes and convert them into tracked tasks in current.md with checkbox state
---

## If scratchpad.md exists

Review scratchpad.md and begin to create tasks we can iterate on in current.md. Use brackets [] so we can easily track the state of a task.

## If scratchpad.md does NOT exist

Do NOT fail silently. Instead:

1. Say: "No scratchpad.md found."
2. Ask the user the following questions (one at a time or together):
   - "What are you working on? (project name or short description)"
   - "What's the goal for this session?"
   - "Any constraints, requirements, or context I should know?"
3. From their answers, create `scratchpad.md` with a short brain dump capturing what they told you.
4. Then immediately convert that into `tasks/CURRENT.md` with checkbox task items [ ] based on the session goal.
5. Confirm: "scratchpad.md and tasks/CURRENT.md created. Ready to work."
