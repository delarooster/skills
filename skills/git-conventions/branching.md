# Git Branching

## Branch Strategy

### Base Branch

`main` is the default base branch. All PRs merge into `main`.

**Do NOT merge directly into `main`.** Always use a pull request.

### Short-Lived Branches

For discrete features, fixes, or changes that warrant isolation from the working branch.

## Branch Naming

### Pattern
```
<type>/<user-initials>/<short-description>
```

### Types

- `feature/` - New functionality or enhancements
- `bugfix/` - Bug fixes
- `hotfix/` - Critical production fixes
- `refactor/` - Code restructuring
- `docs/` - Documentation updates
- `chore/` - Build process, tooling, dependencies

### Examples
```
feature/jd/user-authentication
bugfix/sm/login-validation-error
hotfix/ak/critical-memory-leak
```
