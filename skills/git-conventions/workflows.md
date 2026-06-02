# Git Workflows

## Pull Requests

All code changes require pull requests for review and approval before merging.

**No direct merges into `develop`.** All merges into the base branch go through a PR, even from monthly working branches.

### Workflow

```
Working branch (march, april, etc.)
  │
  ├── commit, commit, commit...
  │
  └── PR into develop ──► review ──► merge
```

### PR into develop

When a working branch is ready to merge:

1. Push working branch to remote
2. Open PR from working branch → `develop`
3. Review changes
4. Merge via PR (not local merge + push)

### AI Agent Behavior

AI agents must NOT merge into `develop` locally and push. Always create a PR using `gh pr create` or instruct the user to open one.
