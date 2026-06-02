# Skill File Format

Convention for agent skills in this workspace. Based on Matt Pocock's skills model (github.com/mattpocock/skills).

## Directory Structure

```
skills/<skill-name>/
├── SKILL.md              # Required — main instruction file
├── reference-1.md        # Optional — bundled reference material
├── reference-2.md        # Optional — additional reference
└── scripts/              # Optional — utility scripts
    └── helper.py
```

Skills are authored in `skills/` (this repo is the source of truth) and deployed to the AI tool's global config directory via `./setup.sh deploy-skills` for cross-project use. The directory name is the skill's invocation name (e.g., `skills/terraform/` → `/terraform`).

## SKILL.md Format

### Frontmatter (required)

```yaml
---
name: skill-name
description: Brief description of capability. Use when [specific triggers].
---
```

**`name`**: Invocation name. Lowercase, hyphenated. Matches directory name.

**`description`**: Max 1024 chars. This is the **only thing the agent sees** in its system prompt when deciding which skill to load. Must include:
- First sentence: what the skill does
- Second sentence: "Use when [specific trigger phrases]"

Good:
```
Create Azure DevOps work items from markdown. Use when user says "create a story", "add a PBI", or "sync backlog".
```

Bad:
```
Helps with backlog items.
```

### Body

Two styles depending on skill type:

**Procedural skill** (50-100 lines): Step-by-step orchestration with checklists.

```markdown
# Skill Name

## Steps

1. [First action]
2. [Second action — reference [detail.md](detail.md) for specifics]
3. [Third action]

## Checklist

- [ ] [Verification step]
- [ ] [Verification step]
```

**Reference loader** (~10 lines): Points the agent at bundled reference files.

```markdown
# Skill Name

Read and apply these references for all [domain] work:

- [file1.md](file1.md) — what it covers
- [file2.md](file2.md) — what it covers
```

### Size limits

| Type | SKILL.md max | Bundled files |
|------|-------------|---------------|
| Procedural | 100 lines | Unlimited |
| Reference loader | 20 lines | Unlimited |

If SKILL.md exceeds 100 lines, split detail into a bundled reference file.

## Bundled Reference Files

These are reference files moved from `rules/<domain>/` into the skill directory. They keep their original content and filenames when useful.

- One source of truth: the file lives in the skill directory, not duplicated in `rules/`
- SKILL.md links to them with relative paths: `[publishing.md](publishing.md)`

## When to Add Scripts

Add utility scripts when:
- Operation is deterministic (validation, formatting)
- Same code would be generated repeatedly
- Errors need explicit handling

Scripts save tokens and improve reliability vs. generated code.
