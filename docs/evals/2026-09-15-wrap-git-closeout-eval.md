# Wrap Skill And Git Closeout Document Quality Evaluation - 2026-09-15

## Summary

```text
╔══════════════════════════════════════════════════════════════╗
║  WRAP + GIT CLOSEOUT EVALUATION — 2026-09-15                ║
╠══════════════════════════════════════════════════════════════╣
║  RAW METRICS                                                ║
║  Files: 2  |  Lines: 208  |  Files >100 lines: 1           ║
╠══════════════════════════════════════════════════════════════╣
║  DIMENSION SCORES                                           ║
║                                                             ║
║  Directive Density    2  (weight 20%)  ratio 0.919 upper   ║
║  Contradiction Count  2  (weight 20%)  0 remaining, 3 fixed ║
║  Redundancy Index     2  (weight 15%)  strict ratio 0.000   ║
║  Specificity Score    2  (weight 20%)  average 1.85         ║
║  Coverage Complete    1  (weight 10%)  ratio 0.700          ║
║  Token Efficiency     2  (weight 15%)  ratio 0.711          ║
║                                                             ║
║  COMPOSITE: 1.90 / 2.00  →  EFFECTIVE                      ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 ISSUES                                               ║
║  1. Density ratio is method-dependent; score is not.        ║
║  2. Eval is self-authored; weight it accordingly.           ║
║  3. /clean is the drain but nothing schedules it.           ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 IMPROVEMENTS SINCE LAST EVAL                         ║
║  1. wrap self-contradiction removed (was the root cause).   ║
║  2. git closeout CURRENT.md write now bounded.              ║
║  3. Register lookup tolerates both casing conventions.      ║
╚══════════════════════════════════════════════════════════════╝
```

## Scope And Method

Two files, both changed by commit `d52e81b` on
`feature/ad/pr-agent-evaluation-remediation`:

- `skills/wrap/SKILL.md` (98 lines)
- `commands/git.md` (110 lines)

Scored against `docs/evaluation-framework.md`, Part 1. This is a targeted file evaluation
in the manner of `2026-09-08-pr-judge-eval.md` and `2026-09-09-story-loop-eval.md`, not a
full instruction-set sweep.

**On directive density method, including a claim this report got wrong.**

An earlier revision of this report asserted that the prior `pr-judge` eval's 0.737 was
"only reachable under sentence-level counting". That is false, and PR 12's judge was right
to flag it. `docs/evals/2026-09-08-pr-judge-eval.md:127-133` computes `101 / 137 = 0.737`
explicitly from **line** counts: 137 nonblank nonheading content lines, 101 of them
actionable directive lines.

The real defect was never the unit. It was that a naive per-line regex does not count
**imperative continuation lines** the way the prior eval did by hand, which is why a first
pass produced 0.39 and 0.33. The prior eval counted continuations as part of their
directive and excluded factual rationale from the directive count, both of which are
semantic judgments.

Three measurements of the same two files:

| Method | Ratio | Score |
|---|---|---|
| Naive per-line regex, no continuations | 0.39 / 0.33 | 0 |
| Sentence-level units | 0.711 | 2 |
| Line-level with continuations attributed to their unit | 0.919 | 2 |

The third is closest to the prior eval's stated method and is reported as the headline
number. It is still an over-count: it attributes every line of a unit to the directive,
including the factual rationale the prior eval deliberately excluded. **No automated
measurement here faithfully replicates a hand-judged semantic count, and this report does
not claim otherwise.**

What survives the disagreement is the score. Every method except the one with a known
counting bug clears the 0.70 threshold, so the dimension scores 2 regardless of which is
preferred. The ratio is method-dependent; the score is not.

## Why This Evaluation Exists

PR 12's judge returned MERGE AFTER FIXES on one FAIL gate: a change whose entire purpose was
removing a contradiction shipped with no evidence from the harness this repository already
maintains for exactly that. The gate was correct, and this report is the response.

## Dimension Detail

### 1. Directive Density — 2 (ratio 0.919, upper bound)

| File | Content lines | Directive lines | Ratio |
|---|---|---|---|
| `skills/wrap/SKILL.md` | 42 | 34 | 0.810 |
| `commands/git.md` | 82 | 80 | 0.976 |
| **Combined** | **124** | **114** | **0.919** |

`commands/git.md` at 0.976 is the clearest evidence of the over-count named above: that
file carries substantial rationale prose, and a faithful semantic count would not score it
near-total. Read the number as an upper bound.

Above the 0.70 threshold under every method except the one with the known continuation-
counting bug. `commands/git.md` carries more explanatory prose than the wrap skill, but
nearly all of it is load-bearing rationale attached to a directive rather than
free-standing narrative, which is the distinction the dimension is meant to catch and the
distinction the automated count cannot make.

### 2. Contradiction Count — 2 (0 remaining)

This is the dimension the change targets, and the evaluation found the change had not
finished the job. **Three conflicts existed after `d52e81b` and were resolved before this
report was written.**

| # | Conflict | Resolution |
|---|---|---|
| 1 | Step 5 says create an `## Open Questions` section; closing line said "Do not add a section" | Closing now reads "Do not add a section these steps do not name" |
| 2 | Steps 3 and 5 say "append"; contract said "Update in place. Do not append" | Contract now forbids appending *narrative*, and names the three permitted additions: a queue entry, a decision row, an open-question line |
| 3 | Step 4 says find "the current in-progress phase section"; the contract defines a queue-only file that has none | Step 4 now falls back to placing `**Next:**` under the queue, and explicitly forbids creating a phase section to hold it |

Conflicts 1 and 2 were introduced by `d52e81b` itself while removing the original one. That
is the finding worth recording: a contradiction fix written without running the harness
traded one conflict for two, and the harness is what caught it. Conflict 3 predates the
commit but was exposed by it, because the new contract is what makes a phase-section-free
`current.md` a legitimate shape.

The original conflict, now gone: the skill opened with "Capture all in-session knowledge to
`tasks/current.md`" and closed with "Do not summarize the whole session."

Cross-file check between the two scored files found no conflict. Both restrict writes to
`current.md` to item state, from different directions: the wrap skill by contract, the git
closeout by bounding its single edit.

### 3. Redundancy Index — 2 (strict ratio 0.000)

Concepts appearing in both files: what may be written to `CURRENT.md`. Neither file
re-explains the other's rule. The wrap skill states the general contract; `commands/git.md`
states the closeout-specific bound and points at the PR body and archived verdict for
everything else. Reference is not redundancy under this rubric.

### 4. Specificity Score — 2 (average 1.85)

Directives name concrete artifacts throughout: `tasks/archive/`, `tasks/DECISIONS.md`,
`tasks/decisions.md`, `tasks/stories/6_completed/`, `tasks/reviews/pr-<N>.md`,
`gh pr view <N> --json state`, the seven judge fields. The two points below maximum are
step 2's "Do not mark tasks complete if they were only partially done", which leaves
partial undefined, and "meaningfully longer", which is deliberately a judgment call but is
still a judgment call.

### 5. Coverage Completeness — 1 (ratio 0.700)

Three gaps, none of them contradictions:

- **Step 2 assumes checkbox state exists.** A `current.md` written as a table rather than a
  checkbox list has no `[ ]` to flip, and the step has no fallback.
- **`/clean` is named as the drain for session narrative, but nothing schedules it.** The
  wrap skill correctly refuses to write narrative and correctly points at `/clean` as
  where it belongs. Nothing in either file causes `/clean` to run. This is the mechanism
  that failed in `another repository`, where `/clean` last ran 2026-09-04 and the file
  accumulated for eleven days.
- **No guidance on a `current.md` that is already bloated.** Both files describe steady
  state. Neither tells an agent what to do when it opens a file that is already 64,242
  bytes, which is the case where the instruction matters most.

### 6. Token Efficiency — 2 (ratio 0.711)

208 lines across both files, one above the 100-line target (`commands/git.md` at 110). The
wrap skill grew from 62 to 98 lines in this change. The growth is contract text that
replaces an ambiguity which was producing 57KB of downstream waste per consuming
repository, so the trade is strongly positive.

## Limitation

**This evaluation was written by the same agent that wrote the change it scores.** It is
evidence that the harness was run and that it found real defects, which is what the FAIL
gate asked for. It is not independent verification. The three contradictions in section 2
are mechanically checkable against the file and should be checked rather than taken on
trust.

## Method Appendix

Directive density script, run against both files with code fences and frontmatter stripped
and headings excluded:

```python
DIRECTIVE = re.compile(r'\b(never|do not|don\'t|must|only|always|use|check|report|'
                       r'require|append|update|remove|find|skip|stop|verify|run|record|'
                       r'mark|replace|keep|leave|match|fall back|write|revert|spawn|poll|'
                       r'wait|obtain|ensure|make|open|push|commit|judge|dispatch|contain|'
                       r'treat|read|point|count|log|surface|confirm)\b', re.I)
```

Two unit models were run against the same regex, which is why this report carries two
ratios:

- **Sentence-level (0.711).** Units are bullets and sentences longer than 15 characters,
  split on sentence boundaries within paragraph chunks.
- **Line-level with continuations (0.919, headline).** Content lines are grouped into
  logical units, a unit starting at a bullet or after a paragraph break. If any part of a
  unit matches the regex, every physical line of that unit counts as a directive line.
  This is the model closest to the prior `pr-judge` eval's `101 / 137`.

The line-level model is an upper bound because it cannot distinguish a directive's
imperative clause from the factual rationale attached to it, and the prior eval excluded
that rationale by hand. Neither model is a substitute for the semantic judgment the rubric
actually asks for. Both are reported so a reader can see the spread rather than a single
number chosen after the fact.
