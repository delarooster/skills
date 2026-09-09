# PR Judge Single-File Document Quality Evaluation - 2026-09-08

## Summary

```text
╔══════════════════════════════════════════════════════════════╗
║  PR_JUDGE FILE EVALUATION — 2026-09-08                      ║
╠══════════════════════════════════════════════════════════════╣
║  RAW METRICS                                                ║
║  Files: 1  |  Lines: 186  |  Files >100 lines: 1           ║
╠══════════════════════════════════════════════════════════════╣
║  DIMENSION SCORES                                           ║
║                                                             ║
║  Directive Density    2  (weight 20%)  ratio 0.737          ║
║  Contradiction Count  1  (weight 20%)  2 internal conflicts ║
║  Redundancy Index     2  (weight 15%)  strict ratio 0.000   ║
║  Specificity Score    2  (weight 20%)  average 1.80         ║
║  Coverage Complete    1  (weight 10%)  ratio 0.684          ║
║  Token Efficiency     1  (weight 15%)  ratio 0.866          ║
║                                                             ║
║  COMPOSITE: 1.55 / 2.00  →  NEEDS WORK                     ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 ISSUES                                               ║
║  1. CI, deployment, and lifecycle facts are stale.          ║
║  2. Local tests violate isolation and write constraints.    ║
║  3. Verdict, TDD, and prior-review procedures have gaps.    ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 IMPROVEMENTS SINCE LAST EVAL                         ║
║  (compare to previous eval in docs/evals/ if one exists)    ║
║  1. N/A — first file-specific evaluation                    ║
║  2.                                                         ║
║  3.                                                         ║
╚══════════════════════════════════════════════════════════════╝
```

The framework leaves `1.51-1.59` unclassified: effective starts at 1.60 and needs
improvement ends at 1.50. This report uses **NEEDS WORK** because 1.55 is below the
effective threshold.

## Scope And Method

The only scored file is:

`<app-repo>/.claude/agents/pr-judge.md`

Current repository files were read only to validate factual claims. They do not
contribute to density, redundancy, specificity, coverage, or efficiency counts.
There is no earlier file-specific evaluation under `docs/evals/`, so no score delta
is available.

Markdown headings inside the fenced verdict template are output payload, not
document structure. They remain in the density denominator. This is consistent
with the fence-aware method used by the 2026-08-31 full-corpus evaluation.

## Raw Metrics

| Measure | Count |
|---|---:|
| Files | 1 |
| Physical lines | 186 |
| Files over 100 lines | 1 |
| Blank lines | 38 |
| Non-fenced Markdown headings | 11 |
| Nonblank, nonheading content lines | 137 |

## Validity Findings

These findings are separate from the six static rubric scores. The rubric rewards
specificity even when a specific directive is factually wrong.

### High: Stacked-PR CI guidance is obsolete

`.claude/agents/pr-judge.md:65-69` says CI only triggers for pull requests targeting
`develop`, so stacked PRs receive no checks and Gate 4 must be UNVERIFIABLE.

`.github/workflows/main.yml:6-12` now deliberately uses an unfiltered
`pull_request:` trigger. `tasks/reviews/pr-106.md:34,48-51` and
`tasks/archive/2026-09-08-stream-a-and-the-pr-judge.md:175-179` already record the
judge rule as stale. Leaving it active can produce false Gate 4 verdicts.

### High: The six gates are attributed to the wrong decision and wrong state

`.claude/agents/pr-judge.md:34` says the six gates come from D-006 and directs the
judge to apply them to every PR.

`tasks/DECISIONS.md:156-176` records the lifecycle under D-001 as a target state and
explicitly says, "Nothing here is in effect." D-006 at
`tasks/DECISIONS.md:263-293` concerns multi-agent delegation. It says a PR-reviewer
agent is safe; it does not establish the six gates.

### High: Gate 5 is not structurally impossible

`.claude/agents/pr-judge.md:46-54` says deployment cannot pass and
`deploy-infrastructure` runs only after a push to `develop`.

`.github/workflows/main.yml:12-17,38-40` also permits `workflow_dispatch`, and the
deployment job runs for that event. `.github/workflows/deploy-bicep.yml:15-26`
independently exposes manual dispatch inputs. A normal PR run still skips deployment,
but a pre-merge branch can be manually deployed. Gate 5 should be evidence-driven,
not hard-coded UNVERIFIABLE.

### High: Local test evidence may come from the wrong revision

`.claude/agents/pr-judge.md:21-23` forbids checkout, while lines 93-94 run tests in
the shared working tree. The procedure never proves that the working tree matches
the PR head. `tasks/reviews/README.md:52-57` already states that the judge cannot
safely run tests until worktree isolation exists.

This can report a passing local test run from an unrelated branch as PR evidence.

### Medium: Acceptance-criteria lookup misses story files

`.claude/agents/pr-judge.md:90-92` reads claimed work only from
`tasks/epics/**/*.md`. Current Stream A work is decomposed into files under
`tasks/stories/1_backlog/`, with the epics retaining only summary rows. A PR claiming
a story can therefore be judged against the wrong scope.

### Medium: Known provenance failure has no procedural fix

`tasks/reviews/README.md:43-46` records two calibration failures caused by not
checking whether a dependency was already present on `origin/develop`. The judge's
procedure still has no explicit base-ref/provenance comparison before attributing a
finding to the PR.

## Dimension Reasoning

### Directive Density - 2

| Measure | Count |
|---|---:|
| Nonblank, nonheading content lines | 137 |
| Actionable directive lines | 101 |
| Directive density | 0.737 |

`101 / 137 = 0.737`, above 0.70, so the score is 2. The semantic count includes
imperative continuations and prescriptive verdict-template fields. It excludes
frontmatter metadata, fences, table separators, factual rationale, and descriptive
repository context.

The file is directive-heavy. Density is not its main weakness.

### Contradiction Count - 1

Two internal conflicts were found:

1. `.claude/agents/pr-judge.md:20` permits writes only to the verdict file, while
   lines 93-94 require `dotnet test`. A normal test run restores/builds and writes
   under `server/**/bin`, `server/**/obj`, and potentially test-results directories.
2. `.claude/agents/pr-judge.md:86` says to read the whole diff, while lines 86-87
   permit skimming generated or repetitive blocks for diffs over roughly 800 lines.
   Skimming a block is not reading the whole diff.

The conditional posting text at lines 178-181 does not conflict with the no-post
rule because it is explicitly disabled until the section changes state.

Two contradictions produce a score of 1.

### Redundancy Index - 2

Thirty-five distinct concepts or workflows were identified:

| Group | Count | Concepts |
|---|---:|---|
| Role/runtime | 3 | Invocation; tool/model configuration; reviewer posture |
| Side-effect boundaries | 6 | Code mutation; write allowlist; git writes; posting; PR-description evidence; Bash boundary |
| Gate system | 7 | Lifecycle/status vocabulary plus six individual gates |
| Repository context | 5 | Base/stacking; frontend tests; Bun updates; dummy services; identity decision |
| Review procedure | 6 | Metadata; diff; CI; work-item scope; local tests; verdict write |
| Findings/verdict | 6 | Severity; brevity; prior findings; document schema; verdict meanings; posting transition |
| Return contract | 2 | Orchestrator payload and verdict path |
| **Total** | **35** | |

The framework defines redundancy across files. With one file, no concept can be
fully re-explained in two or more files: `0 / 35 = 0.000`, so the strict score is 2.

This score is mechanically favorable and should not be read as "no repetition."
Eleven concepts are re-explained in multiple sections of the same file: output
boundaries, writable path, posting, six-gate structure, current-head CI evidence,
Gate 5, Gate 6, finding format, prior findings, verdict schema, and return limits.
The token-efficiency estimate accounts for removable portions of that repetition.

### Specificity Score - 2

| # | Directive summary | Lines | Rating |
|---:|---|---:|---:|
| 1 | Return a verdict, not a patch | 10-12 | 2 |
| 2 | Modify no application code; write only the verdict path | 18-20 | 2 |
| 3 | Use refs instead of git write operations | 21-23 | 2 |
| 4 | Never post to GitHub in advisory mode | 24 | 2 |
| 5 | Do not treat the PR description as evidence | 25-26 | 2 |
| 6 | Report each gate with one of four states and evidence | 34-35 | 2 |
| 7 | Mark Gates 5 and 6 UNVERIFIABLE | 46-56 | 2 |
| 8 | Flag deploy risk for migrations, CI, or Bicep | 53-54 | 2 |
| 9 | Require `develop` as the base and identify stacks | 62-64 | 2 |
| 10 | Apply the stacked-PR CI rule and verify the head SHA | 65-69 | 2 |
| 11 | Do not blame frontend authors for the missing test harness | 70-72 | 2 |
| 12 | Never recommend bare `bun update` | 73-74 | 2 |
| 13 | "Weight findings accordingly" for dummy services | 75-78 | 0 |
| 14 | Block code that depends on an unresolved identity decision | 79-81 | 2 |
| 15 | Fetch the listed PR metadata fields | 85 | 2 |
| 16 | Read the whole diff but skim large repetitive blocks | 86-87 | 1 |
| 17 | Check the claimed backlog scope for over/under-delivery | 90-92 | 2 |
| 18 | Run server tests when they are "cheap" | 93-94 | 1 |
| 19 | Use exactly three lines per finding | 113-115 | 2 |
| 20 | Return only four named values | 183-186 | 2 |

The sample totals `36 / 40`, for an average of `1.80`. This is above 1.50, so the
score is 2.

Specificity and correctness are different. The obsolete stacked-PR rule scores 2
because it will produce consistent behavior, but that behavior is now wrong.

### Coverage Completeness - 1

Nineteen capabilities are relevant to this judge role. Thirteen are covered.

| Capability | Covered | Notes |
|---|---|---|
| Invocation/runtime configuration | Yes | Trigger, tools, and model named |
| Reviewer independence | Yes | Verdict-only posture |
| Filesystem/code-mutation boundary | Yes | Explicit allowlist |
| Git/GitHub side-effect safety | Yes | Explicit prohibitions |
| Evidence standard | Yes | PR body is not proof |
| Base/stack topology | Yes | `develop` and stacking addressed |
| Diff inspection | Yes | Command and large-diff path |
| Six-gate reporting | Yes | States and schema defined |
| CI run/head provenance | Yes | Head-SHA check required |
| Build/server-test checks | Yes | Gate and local command present |
| Work-item scope verification | Yes | Over/under-delivery named |
| Repository-specific traps | Yes | Six risks listed |
| Finding/output format | Yes | Severity, limits, schema, return |
| Exact PR-head test isolation | No | Shared working tree is unverified |
| TDD counterfactual procedure | No | No method proves failure without change |
| Deterministic verdict matrix | No | Findings/gates do not map reliably to verdicts |
| Prior-verdict retrieval | No | Output table exists; input procedure does not |
| Tool/auth/timeout failure handling | No | No fallback or UNVERIFIABLE rule |
| Correctness/security inspection method | No | Severity exists, discovery method does not |

`13 / 19 = 0.684`, within 0.50-0.80, so the score is 1.

### Token Efficiency - 1

| Removable category | Estimated lines |
|---|---:|
| Repeated boundary, gate, and format explanations | 11 |
| Rhetorical rationale and ceremony | 7 |
| Stale or superseded repository statements | 5 |
| Disabled future-posting ceremony | 2 |
| **Estimated removable lines** | **25** |

`(186 - 25) / 186 = 0.866`, within 0.75-0.90, so the score is 1. Most of the file
earns its place, especially the concrete procedure and compact output schema. The
main reduction opportunity is to move volatile repository facts into a separately
maintained rubric and keep the agent definition focused on stable review behavior.

## Composite

```text
composite = (2 * 0.20) + (1 * 0.20) + (2 * 0.15)
          + (2 * 0.20) + (1 * 0.10) + (1 * 0.15)
          = 1.55 / 2.00
```

Result: **NEEDS WORK**, using the below-1.60 interpretation described above.

## Revision Improvements Before This Baseline

There is no prior scored evaluation, but git history shows three improvements since
the initial `ee3c4f1` version:

1. Findings now have explicit line, confidence, quote, and count limits, plus a
   120-line verdict cap.
2. Re-reviews now have a compact prior-findings table and a structured command/outcome
   evidence table.
3. The work-item lookup moved away from deleted `tasks/backlog/`, although the new
   epics-only path still misses story-level acceptance criteria.

## Recommended Corrections

1. Replace the D-006 attribution and unconditional six-gate mandate with the actual
   current review policy. If the lifecycle is intentionally adopted, record that
   decision first.
2. Delete the obsolete stacked-PR CI rule. Query the workflow and current head on
   each run rather than encoding trigger state as a permanent fact.
3. Make deployment evidence-driven. A normal PR run is not deployment evidence, but
   a matching successful manual dispatch can make Gate 5 verifiable.
4. Do not run local tests until isolated worktrees exist. Use CI evidence, or create
   a separate explicitly approved isolation mechanism.
5. Read claimed story and epic files, load the previous verdict before overwriting
   it, and compare the PR diff against its base ref before assigning provenance.
6. Add a deterministic matrix mapping blocking findings, should-fix findings, gate
   failures, and external blockers to the three verdict values.
