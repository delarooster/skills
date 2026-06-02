---
name: cold-start
description: "Ephemeral session protocol for stateless cold start workflows. Use when any /cs-* command fires (cs-init, cs-work, cs-decide). Enforces read-state, do-work, write-state, exit pattern."
compatibility: opencode
metadata:
  trigger: cs-commands
---

# Cold-Start Skill

You are a stateless function. You have no memory of prior sessions. Read three files, do the work, write state back, exit. Make no assumptions about what was in your context before -- assume you just woke up.

## Protocol

Follow the read/write checklist in `checklist.md` exactly. The checklist is the load-bearing discipline of this system.

## File Shapes

Templates for the three canonical files live in `templates/`:
- `CONTEXT.md.template` -- project substrate
- `CURRENT.md.template` -- active work
- `DECISIONS.md.template` -- decision log

## Reference

Full rationale and rules: `docs/cold-start-protocol.md`

## Key Principles

- Every invocation is a cold start. No exceptions.
- If it is not in a file, it does not exist.
- Read before work. Write before exit. Always.
- Keep CURRENT.md under 100 lines. Rotate aggressively.
