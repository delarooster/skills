---
name: plan-project
description: Plan project work by creating epics and stories from initiative goals. Use when user says "create epics", "break down stories", "plan project work", or "create task breakdown".
---

# Plan Project

## Steps

1. **Read initiative context** — read `main.md` (or equivalent brain dump) to understand goals, scope, and definitions

2. **Create epics** — generate epic files in `epics/1_backlog/` using the template in [task-workflow.md](task-workflow.md):
   - One file per epic
   - Include: priority, dependencies, scope, key activities, acceptance criteria
   - Max 100 lines per epic

3. **Break into stories** — generate story files in `stories/1_backlog/` using the template in [task-workflow.md](task-workflow.md):
   - One file per story
   - Include: effort estimate (Fibonacci), dependencies, acceptance criteria
   - Max 75 lines per story
   - Each story references its parent epic

4. **Present to user** — summarize the breakdown for review before proceeding

5. **Manage state** — move files between state folders as work progresses per the state machine in [task-workflow.md](task-workflow.md)

## References

- [task-workflow.md](task-workflow.md) — State machine, templates, writing style, effort scale

## Writing Style

- Narrative over checklist — explain "why this matters"
- Document relationships: initiative → epics → stories (each references parent, never repeats)
- Spell out terms in executive docs, abbreviations OK in technical docs after first definition
