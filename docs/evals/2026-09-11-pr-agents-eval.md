# PR Agent Document Quality Evaluation - 2026-09-11

## Summary

```text
╔══════════════════════════════════════════════════════════════╗
║  PR AGENTS EVALUATION - 2026-09-11                         ║
╠══════════════════════════════════════════════════════════════╣
║  RAW METRICS                                                ║
║  Files: 2  |  Lines: 257  |  Files >100 lines: 1           ║
╠══════════════════════════════════════════════════════════════╣
║  DIMENSION SCORES                                           ║
║                                                             ║
║  Directive Density    2  (weight 20%)  ratio 0.855          ║
║  Contradiction Count  0  (weight 20%)  5 conflicts          ║
║  Redundancy Index     1  (weight 15%)  ratio 0.100          ║
║  Specificity Score    2  (weight 20%)  average 1.65         ║
║  Coverage Complete    1  (weight 10%)  ratio 0.727          ║
║  Token Efficiency     1  (weight 15%)  ratio 0.751          ║
║                                                             ║
║  COMPOSITE: 1.20 / 2.00  ->  NEEDS WORK                    ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 ISSUES                                               ║
║  1. The scorer duplicates the judge and has no active call. ║
║  2. Score and route ownership conflict across the workflow. ║
║  3. Carried blockers and non-finding HOLDs can score zero.  ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 IMPROVEMENTS SINCE LAST EVAL                         ║
║  1. N/A - first evaluation of the two-agent subsystem       ║
║  2.                                                         ║
║  3.                                                         ║
╚══════════════════════════════════════════════════════════════╝
```

## Scope And Method

The scored files are `agents/pr-judge.md` and `agents/verdict-scorer.md`. Active
call sites were inspected to validate the interface, but do not contribute to the
static metric denominators.

For directive density, blank lines and non-fenced headings are excluded. Exact
output fields, decision rows, severity definitions, and scoring anchors count as
directives because they prescribe behavior. Redundancy uses independently
actionable policies as concepts. Coverage is limited to capabilities required by
this review-and-routing subsystem.

The earlier `2026-09-08-pr-judge-eval.md` scored an older copy of only the judge in
another repository. It is useful historical context, but not a valid score-level
baseline for this two-file scope.

## Raw Metrics

| File | Physical lines | Content lines | Directive lines | Density |
|---|---:|---:|---:|---:|
| `agents/pr-judge.md` | 200 | 146 | 127 | 0.870 |
| `agents/verdict-scorer.md` | 57 | 40 | 32 | 0.800 |
| **Total** | **257** | **186** | **159** | **0.855** |

`pr-judge` has active dispatch paths in `commands/git.md:24-26` and
`skills/story-loop/adapter.md:39-40`. `verdict-scorer` appears only in its own
frontmatter and the README catalog. No command or orchestrator invokes it.

## Dimension Reasoning

### Directive Density - 2

`159 / 186 = 0.855`, above the rubric's `0.70` threshold. Both files are highly
directive. Density is not the source of the overlap.

### Contradiction Count - 0

Five conflicts were found, which exceeds the rubric's three-conflict threshold:

1. `pr-judge.md:121-125` requires a blocking claim to end in `[confidence]
   (score)`, while `pr-judge.md:175-184` requires every claim to end in
   `[confidence]` and omits the score from the canonical format.
2. `pr-judge.md:198-200` hard-codes the `HUMAN` route at 8, while
   `verdict-scorer.md:52-53` assigns threshold ownership to the orchestrator.
3. `verdict-scorer.md:3,10-13` promises one number and one justification line,
   while `verdict-scorer.md:43-50` requires four output lines.
4. `verdict-scorer.md:17-21` forbids reading evidence outside the verdict but asks
   the scorer to identify something the judge missed.
5. `pr-judge.md:43-49` makes fallback gates conditional on applicability but
   permits `N/A` only when a repository rubric exists to declare it.

The surrounding story-loop interface adds another inconsistency: it reads only the
judge's five fields at `skills/story-loop/orchestrator.md:142-143`, but later
requires the scorer's `CONCERN` at lines 172-179 without dispatching the scorer.

### Redundancy Index - 1

Four of 40 identified concepts are fully explained in both files:

| Duplicated concept | Judge | Scorer |
|---|---|---|
| Maximum blocking score, or zero | lines 102-103 | lines 25-26 |
| Seven score anchors | lines 105-115 | lines 29-37 |
| Confidence caps | line 117 | line 39 |
| PR attribution and pre-existing defects | lines 118-119 | lines 40-41 |

`4 / 40 = 0.100`, within the rubric's `0.10-0.25` range. The ratio understates the
cost because the duplicated material is the scorer's central purpose rather than
incidental guidance.

### Specificity Score - 2

A 20-directive sample scored `33 / 40 = 1.65`. Strong directives include the
write allowlist, exact-head evidence rules, verdict matrix, score anchors, and
fixed return contracts. Points were lost for terms without operational definitions,
including "relevant project files," "repository rubric," "core metadata," and
the scorer's `CONCERN` mechanism.

### Coverage Completeness - 1

Sixteen of 22 role-specific capabilities are covered, for `16 / 22 = 0.727`.
Review acquisition, evidence provenance, side-effect safety, findings, scoring,
and artifact creation are covered. The missing capabilities all concern the
unimplemented two-stage design:

1. A caller that dispatches `verdict-scorer`.
2. A judge-to-scorer handoff contract.
3. One authority when stored and recomputed scores differ.
4. Enough retained data to score OPEN or PARTIAL prior blockers.
5. Malformed or incomplete verdict handling.
6. Coherent ownership of thresholds and concerns.

### Token Efficiency - 1

An estimated 64 lines are removable without losing active behavior: all 57 lines
of the uncalled scorer, five lines from the judge's duplicate score-placement
example, and two lines of fixed-route wording. `(257 - 64) / 257 = 0.751`, within
the rubric's `0.75-0.90` range.

## Composite

```text
composite = (2 * 0.20) + (0 * 0.20) + (1 * 0.15)
          + (2 * 0.20) + (1 * 0.10) + (1 * 0.15)
          = 1.20 / 2.00
```

Result: **NEEDS WORK**.

## Interface Findings

### High: Two score producers have no authority rule

`pr-judge.md:100-125` computes escalation from direct evidence and writes it to
both the verdict and return value. `verdict-scorer.md:23-41` recomputes the same
value from a lossy rendered artifact. Nothing defines which value wins when they
differ. The judge has the stronger evidence position, so rescoring adds drift
without adding independent information.

### High: Routing ownership conflicts with story-loop configuration

`pr-judge.md:198-200` stores `HUMAN` for scores at least 8. Story-loop allows a
per-repository threshold and routes from the raw number at
`skills/story-loop/orchestrator.md:145-162`. A repository threshold of 9 makes a
score of 8 simultaneously `HUMAN` in the verdict and `AUTO` in the orchestrator.

### High: Existing blockers can disappear from escalation

`pr-judge.md:96-98,184-186` keeps OPEN and PARTIAL prior findings only in a compact
table without score or confidence. A scorer following `verdict-scorer.md:25-26`
can return zero when the current Blocking section says `None.`, despite a carried
blocker still forcing HOLD.

### Medium: HOLD and escalation represent different conditions

The verdict matrix permits HOLD for unavailable core evidence or an unresolved
external prerequisite, but escalation derives only from BLOCKING findings. A HOLD
can therefore return zero and enter story-loop's "Nothing blocking" route. The
contract needs either a blocking finding for every HOLD or an explicit non-score
route for incomplete evidence and prerequisites.

## Recommendation

Consolidate on `pr-judge`:

1. Keep evidence review, finding severity, and raw escalation scoring together in
   `pr-judge`.
2. Make the invoking command or orchestrator the sole owner of routing thresholds.
   Remove `Route` from the stored verdict.
3. Resolve the two finding schemas into one scored format for BLOCKING findings.
4. Either add `CONCERN` to the judge's return contract or remove the unreachable
   scorer language from story-loop.
5. Require every HOLD condition to identify whether it blocks remediation, needs
   human input, or is only unverifiable.
6. Retire `verdict-scorer` and remove its README entry. Account for already
   deployed copies because Claude agent deployment is additive.

This keeps one evidence authority and one routing authority. A separate scorer is
justified only if independent calibration is a real requirement. In that design,
remove scoring from the judge, invoke the scorer explicitly, preserve complete
finding data in the verdict, and define mismatch and malformed-input behavior. It
will be less concise and currently has no active consumer.

## Expected Post-Change Result

The recommended consolidation removes at least 64 lines from the scored pair and
eliminates the cross-agent score duplication. The main quality gain will come from
resolving the finding-format, route-ownership, gate-applicability, and HOLD-routing
conflicts; line reduction alone does not improve the contradiction score.
