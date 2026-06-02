---
description: Bootstrap a session — load workspace rules from skills and resume from the last known task state in tasks/
---

Read your instructions in ~/repos/skills folder to understand the project and the context.

Then, check for task files in the tasks/ directory. Look for files in this order:

tasks/CURRENT.md
tasks/TASKS.md
tasks/main.md
Read whichever file exists to understand the project status and current work.

## If no task files exist

This is a new or uninitialized project. Do NOT silently fail or wait. Instead:

1. Look for: tasks/scratchpad.md
   - Create a tasks/CURRENT.md with iterable tasks to work against in the next session.
2. Say: "No task files found. This looks like a new project."
3. Ask the user: "What are you building? Give me a short description and I'll help you get started."
4. Once they respond, offer to:
   - Create `scratchpad.md` with their description as a starting brain dump
   - Create `tasks/CURRENT.md` with an initial task list
   - Or run `/begin` if they already have notes to work from
5. Create whichever files the user approves, then confirm the session is ready.

## If no scratchpad.md exists but tasks/ files do

Resume from the task files. No action needed on scratchpad.

## If you are not sure what to do, ask the user for help.

## If you are not sure how to do something, ask the user for help.
