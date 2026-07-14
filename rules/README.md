# Skills Catalog

On-demand agent skills for domain-specific conventions and workflows. Skills load only when triggered — they are **not** read at startup.

Skills are authored in `skills/` (this repo is the source of truth) and deployed via `./setup.sh` for cross-project use: `~/.config/opencode/skills/` (`deploy-skills`), `~/.agents/skills/` (`deploy-codex-skills`), and additively into `~/.claude/skills/` (`deploy-claude-skills`).

## Available Skills

| Skill | Trigger | What it does |
|-------|---------|-------------|
| `/bicep` | Working with `.bicep` files, modules, private DNS, private endpoints | Loads resource reference, hub/spoke DNS, and style conventions |
| `/bicep-modules` | Bumping versions, modifying modules published to ACR | Semver classification, version bump workflow, publishing conventions |
| `/terraform` | Working with `.tf` files, modules, `tofu test` | Loads structure, style, and testing conventions |
| `/plan-project` | "create epics", "break down stories", "plan project work" | Creates epics/stories from initiative goals |
| `/git-conventions` | Creating branches, writing commits, opening PRs | Loads branch naming, commit format, PR workflow |
| `/cold-start` | `/cs-init`, `/cs-work`, `/cs-decide` | Ephemeral session protocol -- stateless read/work/write cycles |
| `/wrap` | end of session, "wrap up", "close session" | Persists in-session context to tasks/current.md |

## How Skills Work

- **At startup:** Agent sees only the skill names and one-line descriptions above
- **When triggered:** Agent loads the full SKILL.md + bundled reference files for that skill
- **Token savings:** ~1,350 lines of reference material load on-demand instead of unconditionally

See [docs/skills-format.md](../docs/skills-format.md) for the skill file format convention.
