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

This copies skills and slash commands to `~/.config/opencode/` so they're available across all projects.

### 3. Configure Your AI Tool

**Startup Instructions:**

All tools use the same startup instructions. See [docs/startup-template.md](startup-template.md) for the canonical template.

#### **OpenCode:**

`./setup.sh` deploys `commands/startup.md` to `~/.config/opencode/commands/` automatically. Run with: `/startup`

#### **Claude Code:**

Create `~/.claude/skills/startup/SKILL.md` on your machine and copy content from `docs/startup-template.md`. Run with: `/startup`

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

