# Getting Started

## What is skills?

Workspace-wide rules and patterns for AI-assisted development. Ensures consistency across all projects.

## Quick Setup

### 1. Clone to ~/repos
```bash
mkdir -p ~/repos
cd ~/repos
git clone <repository-url> skills
```

### 2. Deploy Skills and Commands

```bash
cd ~/repos/skills
./setup.sh
```

Run with no arguments, `./setup.sh` scans your machine for installed AI coding tools (OpenCode, Codex, Claude Code) and prompts per tool before deploying this repo's skills, commands, and rules to each one it finds. Add `-y` to accept every detected tool without prompting (`./setup.sh -y`).

Prefer to be explicit? Deploy to one tool directly — `./setup.sh opencode`, `./setup.sh codex`, or `./setup.sh claude` — or use the granular targets (`deploy-claude-skills`, `deploy-claude-rules`, …). Run `./setup.sh help` for the full list. Destinations: `~/.config/opencode/` (OpenCode), `~/.agents/skills` (Codex), and `~/.claude/` (Claude Code).

### Removing / iterating

Testing a new skill or want a clean slate? `./cleanup.sh` reverses a deploy. It scans for deployed content and prompts per tool (defaulting to No), `-y` removes from everything it finds, and `./cleanup.sh claude` (or `claude-rules`, etc.) targets one thing. Removal is name-based and surgical: only the skills, commands, and the delimited `CLAUDE.md` rules block that this repo owns are removed — your own skills, commands, and notes are never touched.

### 3. Configure Your AI Tool

**Startup Instructions:**

All tools use the same startup instructions. See [docs/startup-template.md](startup-template.md) for the canonical template.

#### **OpenCode:**

`./setup.sh` deploys `commands/startup.md` to `~/.config/opencode/commands/` automatically. Run with: `/startup`

#### **Claude Code:**

`./setup.sh` deploys skills and commands to `~/.claude/skills` and `~/.claude/commands`, and merges `INSTRUCTIONS.md` into `~/.claude/CLAUDE.md` (global memory, loaded every session) inside a delimited, auto-managed block. Deployment is additive: it only adds/updates this repo's own skills, commands, and rules block, and never deletes anything else already in `~/.claude`. Run with: `/startup`

#### **Other Tools:**

Add to custom instructions — copy content from `docs/startup-template.md`.

## What Gets Loaded

When AI reads skills:

1. **INSTRUCTIONS.md** - AI behavior rules and git security
2. **rules/README.md** - Available skills catalog
3. **skills/** - On-demand domain skills (load only when triggered)

## First Use

```
You: /startup
AI: Reads INSTRUCTIONS.md and rules/
AI: Adopts robot behavior and lockdown mode
You: "Add user authentication feature"
AI: Makes changes, presents diff, waits for approval
```

## Key Behaviors

- **Robot mode:** Terse, concise communication
- **Git lockdown:** No commits/pushes without explicit approval
- **Pattern compliance:** Follows loaded skill conventions

## Model Access

