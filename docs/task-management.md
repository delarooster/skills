# Working Process with AI Agents

## The Context Problem

LLM sessions lose context over time. Token limits, conversation length, and session resets force you to re-explain project goals repeatedly.

**Solution:** Create persistent "brain dump" files that survive session boundaries.

## The Brain Dump Workflow

### 1. Run Initial Command

```
/startup  # or your custom command
```

AI loads workspace rules from `~/repos/skills`.

### 2. Create Your Brain Dump File

**Before generating any code**, create a context file explaining your project:

```
You: Create a file called CONTEXT.md (or main.md, OVERVIEW.md, etc.)
     explaining what we're building and why
```

**What to include:**
- Project goals and motivation
- Key requirements
- Architecture decisions
- Important constraints
- Terminology and abbreviations
- Success criteria

**Example structure:**
```markdown
# Project Name

## Goal
[1-2 paragraphs: what you're building and why it matters]

## Requirements
- Requirement 1
- Requirement 2
- Requirement 3

## Constraints
- Technical constraints
- Timeline constraints
- Resource constraints

## Abbreviations
| Term | Definition |
|------|------------|
| API  | Application Programming Interface |
| DB   | Database |
```

### 3. Generate Reviewable Artifacts

Now AI can generate structured work files for your review:

**Tasks/Stories:**
```
You: Break this down into tasks in a tasks/ folder
AI: Creates tasks/001-setup-database.md
AI: Creates tasks/002-build-api.md
AI: Creates tasks/003-add-authentication.md
```

**Documentation:**
```
You: Create architecture documentation in docs/
AI: Creates docs/architecture.md
AI: Creates docs/api-spec.md
```

**Implementation Plans:**
```
You: Create implementation plan for authentication
AI: Creates plans/authentication-implementation.md
```

### 4. Review Before Execution

All work is in **reviewable markdown files** before code changes happen.

You can:
- Read and understand the plan
- Request modifications
- Approve specific tasks
- Reject or defer work

### 5. When Context Is Lost

**New session starts, AI forgot everything:**

```
You: /startup
AI: [Loads workspace rules]

You: Read CONTEXT.md and tasks/ folder to understand the project
AI: [Reads persistent files]
AI: [Continues from last known state]
```

**The brain dump file persists across sessions.** Context survives.

## Real Example: Project Planning

Example structure for a planning repo:

```
main.md                    # Brain dump: initiative goals and definitions
tasks/TASKS.md            # Workflow instructions for AI agent
epics/1_backlog/          # High-level work breakdown
stories/1_backlog/        # Detailed task breakdowns  
docs/                      # Generated documentation
```

**Process:**
1. User writes `main.md` with migration goals, context, definitions
2. AI reads `main.md` + `tasks/TASKS.md` for workflow instructions
3. AI generates epics in `epics/1_backlog/`
4. User reviews epic files, requests changes
5. AI breaks epics into stories in `stories/1_backlog/`
6. User reviews stories, approves specific work
7. AI executes approved stories, generates code
8. **New session:** AI reads `main.md` + existing files → continues work

## Why This Works

**Persistent context:**
- Brain dump survives session resets
- New AI sessions can pick up where old ones left off
- No need to re-explain project every time

**Reviewable process:**
- All planning happens in markdown files first
- You review and approve before code changes
- Clear audit trail of decisions

**Structured workflow:**
- Hierarchy: Initiative → Epics → Stories → Tasks
- State tracked by folder location (backlog → in-progress → completed)
- AI follows documented process in TASKS.md

## Key Files

**Required:**
- Brain dump file (`CONTEXT.md`, `main.md`, `OVERVIEW.md`, etc.)
  - Your project goals and requirements
  - AI reads this first in every session

**Optional but recommended:**
- `tasks/TASKS.md` - Workflow instructions for AI
- Task breakdown files in organized folders
- Documentation in `docs/` folder

## Archiving

**Archiving lifts content out of a file. It never deletes the file.**

A decision log, an execution-order document or a story file is linked to from
everywhere else. Replacing one with a dated snapshot at a new path breaks every
link pointing at it, silently, and the breakage surfaces later as an agent reading
nothing and carrying on.

On 2026-09-24 an archive pass in one repo snapshotted the decision log and the
execution order and then deleted both. 176 files linked to the first and 59 to the
second. Its own archive note said the live file should keep every heading, so the
deletion contradicted the plan written moments earlier.

So: snapshot if you like, trim the live file down to what still matters, and leave
it exactly where everything expects to find it. If a file genuinely should stop
existing, that is a decision for a human, not a side effect of tidying.

## Getting Started

**First time:**
```
You: /startup
You: Create CONTEXT.md explaining [your project]
AI: [Creates brain dump file]
You: Review and refine CONTEXT.md
You: Now break this into tasks
AI: [Creates task files for review]
```

**Subsequent sessions:**
```
You: /startup
You: Read CONTEXT.md and understand the project
AI: [Reads brain dump, continues work]
```

The brain dump file is your persistent memory across all AI sessions.
