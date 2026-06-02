# Bicep Module Versioning & Publishing

## Version Convention

Every publishable module must have `// version: x.y.z` as its **first line**.

```bicep
// version: 1.2.0
param location string
...
```

Files under `modules/models/` are **exempt** -- they export types only and are not versioned independently.

## Semver Classification Rules

| Bump  | Trigger |
|-------|---------|
| MAJOR | Parameter removed |
| MAJOR | Parameter type changed |
| MAJOR | Parameter default removed (optional -> required) |
| MAJOR | Output removed |
| MAJOR | Output type changed |
| MAJOR | Exported type shape changed (fields removed or types changed) |
| MINOR | New parameter added WITH a default value |
| MINOR | New output added |
| MINOR | New exported type added |
| MINOR | New optional fields added to an exported type |
| PATCH | Bug fixes to implementation logic |
| PATCH | Documentation/comment changes |
| PATCH | Internal variable refactoring (no param/output change) |

The highest applicable bump wins. MAJOR > MINOR > PATCH.

## Workflow

Before committing changes to a module:

1. Compare current params/outputs against the previous version:
   ```bash
   git show HEAD:path/to/module.bicep
   ```
2. Classify each change using the table above.
3. Determine the minimum required bump (highest severity wins).
4. Read the current `// version:` line and apply the bump.
5. Rewrite the first line with the new version.
6. In the commit message, include the version transition and reason:
   ```
   private-endpoint 1.0.0 -> 1.1.0 (new optional param: tags)
   ```

## Publishing

Modules publish to ACR on merge to `master` via the Azure DevOps pipeline:

```
br:contosoacr.azurecr.io/modules/{module-name}:{version}
```

- Publishing is automatic -- no manual push required.
- **Duplicate versions will FAIL the build.** Always bump before merging.

## Model Files

Files under `modules/models/` export types only:

- No `// version:` comment.
- Not published independently.
- Changing a model type's shape is a **BREAKING** change for all consuming modules.
- Every module that imports the changed type needs a **MAJOR** bump.

To find consumers:

```bash
grep -rl "import.*from.*models/{model-file}" modules/
```

## Checklist

- [ ] Version line updated in each modified module
- [ ] Bump level matches or exceeds the interface change severity
- [ ] Commit message includes version transition
- [ ] Model type changes trigger version bumps in consuming modules
- [ ] No duplicate version exists in ACR (pipeline will catch this, but avoid it)
