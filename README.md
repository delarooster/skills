# Skills

Workspace-wide AI behavior rules and on-demand agent skills for consistent development patterns across all projects.

## Repository Structure

```
skills/
├── INSTRUCTIONS.md          → AI behavior rules and git security lockdown
├── setup.sh                 → Deploy skills, commands, and rules to opencode, codex/agents, and claude
├── cleanup.sh               → Remove deployed content (surgical: only files this repo owns)
├── docs/                    → Process guidance for working with AI
├── rules/                   → Skills catalog (slim index)
├── commands/                → Slash commands (source of truth)
│   ├── startup.md           → Bootstrap session and resume task state
│   ├── begin.md             → Convert scratchpad notes into tracked tasks
│   ├── clean.md             → Archive work and reset for next session
│   ├── git.md               → Branch, commit, push, open PR
│   ├── eval.md              → Score instruction set quality
│   ├── cs-init.md           → Initialize cold-start project files
│   ├── cs-work.md           → Cold-start work session
│   └── cs-decide.md         → Cold-start decision mode
└── skills/                  → On-demand agent skills (source of truth)
    ├── terraform/           → OpenTofu/Terraform conventions
    ├── plan-project/        → Epic/story planning from initiative goals
    ├── git-conventions/     → Branch naming, commits, PR workflows
    ├── cold-start/          → Ephemeral session protocol
    └── wrap/                → Session closing ritual
```

## Quick Start

### 1. Setup Location

Clone to `~/repos` for consistent workspace organization:

```bash
mkdir -p ~/repos
cd ~/repos
git clone <repository-url> skills
```

### 2. Configure AI Tool

**OpenCode:**

Create `.opencode/commands/startup.md` in your project:

```markdown
---
description: Load project context and skills
---

Read your instructions in ~/repos/skills folder to understand the project and the context.
```

**Claude Code:**

Run `./setup.sh deploy-claude` (or plain `./setup.sh`). This deploys skills to `~/.claude/skills`, commands to `~/.claude/commands`, and merges `INSTRUCTIONS.md` into `~/.claude/CLAUDE.md` (global memory, read every session) inside an auto-managed block — additive, so nothing else already in `~/.claude` is touched.

**Other Tools:**

Add to custom instructions:
```
Read your instructions in ~/repos/skills folder to understand the project and the context.
```

### 3. Read Process Documentation

See [docs/getting-started.md](docs/getting-started.md) and [docs/task-management.md](docs/task-management.md) for workflow guidance.

## What's Included

### INSTRUCTIONS.md
AI behavior rules enforced across all sessions:
- Repository context protocol (identify working directory at session start)
- Robot communication protocol (terse, concise, no enthusiasm)
- Git operations lockdown (no autonomous commits/pushes)
- Required reading directives

### docs/
Process guidance for effective AI-assisted development:
- **getting-started.md** - Setup and first use
- **task-management.md** - Brain dump workflow and context persistence

### skills/ (On-Demand Agent Skills)
Domain-specific conventions and workflows that load only when triggered. This repo is the **source of truth** — edit skills here, then deploy to your AI tool's global config with `./setup.sh deploy-skills`.

- **terraform/** - Infrastructure code structure, style, and testing patterns
- **plan-project/** - Epic/story creation from initiative goals
- **git-conventions/** - Branch naming, commit format, PR workflows
- **cold-start/** - Ephemeral session protocol (stateless read/work/write cycles)
- **wrap/** - Session closing ritual (persist context to tasks/current.md)

## Key Features

### Git Security Lockdown
AI agents cannot autonomously:
- Commit code without explicit approval
- Push to remote without confirmation
- Force push, amend commits, or bypass hooks
- Modify git configuration

All git operations require explicit user commands.

### Robot Communication Mode
AI uses terse, technical communication:
- No enthusiasm or congratulations
- Direct status reporting
- Multiple options for decisions
- Clear action statements

### Brain Dump Workflow
Create persistent context files (CONTEXT.md, main.md) that survive session boundaries:
- Document project goals before generating code
- Generate reviewable markdown artifacts first
- New sessions read brain dump to restore context

See [docs/task-management.md](docs/task-management.md) for detailed workflow.

## Available Skills

See [rules/README.md](rules/README.md) for the skills catalog with trigger phrases.

Skills load on-demand — only the skill descriptions (~1 line each) are visible at startup. Full reference material loads when triggered, saving ~1,300 lines of context tokens per session.

## Usage

```bash
# Easy path: scan for installed tools (OpenCode, Codex, Claude Code) and
# prompt per tool before deploying skills, commands, and rules to each.
./setup.sh
./setup.sh -y                    # accept all detected tools, no prompts

# Explicit single tool
./setup.sh opencode
./setup.sh codex
./setup.sh claude

# Granular targets (for upgrades / source-of-truth control).
# Claude Code (~/.claude) is additive: only adds/updates this repo's own
# skills, commands, and rules block; never deletes anything else you have.
./setup.sh deploy-skills
./setup.sh deploy-commands
./setup.sh deploy-claude-skills
./setup.sh deploy-claude-commands
./setup.sh deploy-claude-rules   # merges INSTRUCTIONS.md into ~/.claude/CLAUDE.md
./setup.sh help                  # full command list

# Undo / iterate: remove what was deployed. Name-based and surgical — only
# files this repo owns are deleted, and only the delimited rules block is
# stripped from ~/.claude/CLAUDE.md. Your own skills/commands/notes stay.
./cleanup.sh                     # scan for deployed content, prompt per tool
./cleanup.sh -y                  # remove from all detected, no prompts
./cleanup.sh claude              # remove from one tool
./cleanup.sh claude-rules        # strip only the CLAUDE.md rules block

# In your project
/startup

# AI identifies repository and loads workspace rules
# Output: "REPOSITORY: your-project | WORKSPACE RULES: skills"

# AI adopts robot behavior and lockdown mode

# Create brain dump file for project context
"Create CONTEXT.md explaining this project"

# Review, then approve work
"Proceed with implementation"
```

## Documentation

- [Getting Started](docs/getting-started.md) - Setup and configuration
- [Task Management](docs/task-management.md) - Brain dump workflow and process
