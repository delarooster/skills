# Story Loop Skill Document Quality Evaluation - 2026-09-09

## Summary

```text
╔══════════════════════════════════════════════════════════════╗
║  SKILLS EVALUATION — 2026-09-09 (story-loop)                 ║
╠══════════════════════════════════════════════════════════════╣
║  RAW METRICS                                                ║
║  Files: 9  |  Lines: 620  |  Files >100 lines: 2            ║
╠══════════════════════════════════════════════════════════════╣
║  DIMENSION SCORES                                           ║
║                                                             ║
║  Directive Density    1  (weight 20%)  ratio 0.599          ║
║  Contradiction Count  1  (weight 20%)  2 cross-file conflicts║
║  Redundancy Index     0  (weight 15%)  ratio 0.333          ║
║  Specificity Score    2  (weight 20%)  average 1.85         ║
║  Coverage Complete    1  (weight 10%)  ratio 0.667          ║
║  Token Efficiency     2  (weight 15%)  ratio 0.919          ║
║                                                             ║
║  COMPOSITE: 1.20 / 2.00  →  NEEDS WORK                     ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 ISSUES                                               ║
║  1. Six concepts fully restated across two or three files.  ║
║  2. OD-1 was decided but never written into the artifact.   ║
║  3. No implementer brief template, though all hinges on it. ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 IMPROVEMENTS SINCE LAST EVAL                         ║
║  1. N/A — first evaluation of this artifact.                ║
║  2.                                                         ║
║  3.                                                         ║
╚══════════════════════════════════════════════════════════════╝
```

## Scope And Method

Scored files, all authored 2026-09-09:

```
skills/story-loop/{SKILL,orchestrator,chain,adapter,pacing}.md
skills/story-loop/runner-{claude,codex,opencode}.md
commands/story-loop.md
```

`skills/story-loop/scripts/*.sh` (549 lines) are **code, not instructions**, and are
excluded from every ratio. They are relevant to the reading only insofar as they
absorb logic that would otherwise be prose; see the density note below.

Fenced content stays in the density denominator, consistent with the 2026-09-08
pr-judge evaluation. Fence delimiters themselves are counted as non-directive.
Return-contract and adapter templates inside fences are counted as directives:
they specify exact required output, which is the strictest form of directive.

This is the first evaluation of this artifact, so no score delta is available for
it. The corpus and pr-judge figures below are context, not comparison.

## Raw Metrics

| File | Lines | Blank | Headings | Fenced | Content |
|---|---:|---:|---:|---:|---:|
| SKILL.md | 100 | 27 | 7 | 4 | 66 |
| orchestrator.md | 123 | 33 | 10 | 17 | 80 |
| chain.md | 112 | 32 | 10 | 16 | 70 |
| adapter.md | 46 | 9 | 4 | 13 | 33 |
| pacing.md | 23 | 5 | 2 | 0 | 16 |
| runner-claude.md | 60 | 17 | 7 | 9 | 36 |
| runner-codex.md | 63 | 20 | 7 | 14 | 36 |
| runner-opencode.md | 62 | 20 | 6 | 17 | 36 |
| commands/story-loop.md | 31 | 9 | 3 | 0 | 19 |
| **Total** | **620** | **172** | **56** | **90** | **392** |

Two files exceed 100 physical lines. `docs/skills-format.md` caps `SKILL.md` at 100
for procedural skills and leaves bundled references unlimited, so `orchestrator.md`
(123) and `chain.md` (112) are within the house rule. `SKILL.md` sits exactly at
100, with no margin for growth.

## Dimension Detail

### 1. Directive Density — 1 (ratio 0.599)

| File | Directive | Content | Ratio |
|---|---:|---:|---:|
| commands/story-loop.md | 16 | 19 | 0.842 |
| SKILL.md | 51 | 66 | 0.773 |
| orchestrator.md | 57 | 80 | 0.713 |
| runner-claude.md | 21 | 36 | 0.583 |
| runner-codex.md | 21 | 36 | 0.583 |
| runner-opencode.md | 21 | 36 | 0.583 |
| adapter.md | 19 | 33 | 0.576 |
| pacing.md | 7 | 16 | 0.438 |
| **chain.md** | **22** | **70** | **0.314** |
| **Total** | **235** | **392** | **0.599** |

Just under the 0.70 threshold for a 2, and one file is responsible.

`chain.md` is the lowest-density file in the set and it carries the single most
important rule. Forty-eight of its seventy content lines are narrative: the story
of the six unstacked pull requests, why unstacked is wrong rather than untidy, why
sequential mode avoids restacking. The argument is sound and it is the reason the
rule will survive contact with a future editor, but the rubric measures directives
and this file is mostly justification.

Note the countervailing effect the ratio cannot see: moving chain-head derivation,
eligibility, parent computation and the base check into `loop-state.sh` removed the
prose that would otherwise have described those algorithms. Density would read
higher if that logic had stayed in Markdown as step-by-step instructions, and the
artifact would be worse. The metric mildly penalises the correct decision.

### 2. Contradiction Count — 1 (2 cross-file conflicts)

Nothing inside the skill contradicts itself. Both conflicts are with the existing
corpus, and both trace to the same root: **OD-1 and the authorization grant were
decided in the task document and never written into the shipped artifact.**

**High: remediation rounds versus reviewer segregation.**
`commands/git.md:9-11` states that invoking `/git` "is **not** authorization to act
on anything the judge finds," and that findings are the user's to triage.
`skills/story-loop/orchestrator.md:65-69` mandates the opposite inside the loop:
blocking findings go back to the same warm implementer for up to two rounds.

The task document settled this as OD-1 option A, a bounded supersession with fresh
verifier context per round. The shipped skill never says so. An agent reading both
files has an unresolved conflict and no stated precedence.

**High: standing grant versus "No exceptions."**
`INSTRUCTIONS.md:27` states that all git write operations require an explicit user
command, "**No exceptions.**" `skills/story-loop/SKILL.md:10-16` asserts a standing
grant covering branch creation, commits, pushes and pull request creation for
queued stories.

A standing grant issued by invoking the command is a defensible reading of
"explicit user command," but neither file makes that argument. As written, the
global rule forbids what the skill authorises.

**Minor, not counted: rows per iteration.**
`orchestrator.md:13` says append exactly one row per iteration. `SKILL.md:55` says
every stop writes a final log row naming the condition. A stop that coincides with
a completed story produces two rows. The ambiguity is resolvable by any reasonable
agent, so it is recorded rather than scored.

### 3. Redundancy Index — 0 (ratio 0.333)

Eighteen distinct concepts. Six are fully re-explained rather than referenced:

| Concept | Explained in | Verdict |
|---|---|---|
| Authorization boundary | SKILL.md, commands/story-loop.md | Redundant |
| Read-nothing rule | SKILL.md, orchestrator.md, commands/story-loop.md | Redundant, 3x |
| `BASE` check | chain.md, SKILL.md, commands/story-loop.md | Redundant, 3x |
| One iteration per invocation | SKILL.md, pacing.md, commands/story-loop.md | Redundant, 3x |
| Stalled-dependency handling | SKILL.md, orchestrator.md | Redundant |
| Depth cap behaviour | SKILL.md, chain.md, adapter.md | Redundant, 3x |
| Chain head derivation | chain.md | Clean |
| Adapter probe order | adapter.md | Clean |
| Return contract | orchestrator.md | Clean |
| Queue membership | orchestrator.md | Clean |
| Log columns | orchestrator.md | Clean |
| Verifier dispatch and CI wait | orchestrator.md | Clean |
| Remediation bounds | orchestrator.md | Clean |
| Stop conditions | SKILL.md | Clean |
| Host spawn / isolate / resume | runner-*.md | Clean |
| Same-session loop caveat | pacing.md, referenced by runner-claude.md | Clean |
| `forge: none` | adapter.md defines, chain.md notes one consequence | Clean |
| Parent computation | chain.md canonical, others summarise and link | Clean |

6 / 18 = 0.333, which is above the 0.25 failure threshold.

**The worst offender is `commands/story-loop.md`.** Its own acceptance criterion
says it must be "a dispatcher, not a manual," and it restates the authorization
boundary, the read-nothing rule and the `BASE` check in full. Nineteen content
lines at 0.842 density look excellent in isolation and are almost entirely
duplication. It should load the skill, name the two failure modes in one line each,
and link.

The second pattern is hub-and-spoke drift: `SKILL.md` summarises what the reference
files explain, which is correct structure, but for six concepts the summary grew
into a complete statement of the rule. Two copies of a rule is two things to keep
in sync.

### 4. Specificity Score — 2 (average 1.85)

Twenty sampled directives: seventeen scored 2, three scored 1, none scored 0.

Representative 2s: the forbidden-operation list; `2_ready` before `1_backlog`;
"the last row whose outcome is `landed` or `partial` **and** whose branch is not
`-`"; "at most 2 rounds"; "a mismatch is `blocked :: unstacked`, not a warning";
"Passing `--base` is not optional and is not a default"; story id taken from the
leading token of the first `# ` heading with filename-stem fallback.

The three 1s:

- **"roughly four minutes"** (`orchestrator.md:59`). Inherited from `commands/git.md`,
  where it is equally soft. Two agents will pick different timeouts.
- **"under 10% of the window"** (`orchestrator.md:18`). A precise number an agent has
  no reliable way to measure mid-run. Specific to read, unverifiable to apply.
- **"the conventions to load"** (`orchestrator.md:36`, `SKILL.md:37`). The brief is
  the heart of the design and this phrase is the only description of a third of it.
  See the coverage finding.

This is the strongest dimension, and it is strongest exactly where the scripts
back it: a directive that names a subcommand and its arguments cannot be vague.

### 5. Coverage Completeness — 1 (ratio 0.667)

Fifteen domains the loop must handle. Ten covered, three partial, two absent.

| Domain | Status |
|---|---|
| Queue selection and ordering | Covered |
| Dependency resolution, including unsatisfiable | Covered |
| Chain head and parent computation | Covered |
| Implementer spawn, three hosts | Covered |
| Verifier dispatch and independence | Covered |
| Remediation bounds | Covered |
| Log format and cold-start resume | Covered |
| Adapter discovery | Covered |
| Pacing | Covered |
| Authorization boundary | Covered |
| Story file state moves | Partial — "per the state machine", no folder-by-outcome mapping |
| Crash recovery | Partial — worktree pruning named only in `runner-codex.md` |
| Forge abstraction | Partial — `gh`-shaped `pr create --base` and `none`; no Azure DevOps, despite two ADO skills in this workspace |
| **Implementer brief template** | **Absent** |
| **TDD linkage** | **Absent** |

**The brief template is the significant gap.** Every guarantee in this design rests
on what gets handed to a clean-context subagent, and the skill describes that
artifact rather than providing it: "the story path, the computed parent, the
conventions to load, and the return contract. Nothing else." A future agent must
compose the brief from prose every iteration, which is precisely the kind of
regeneration `docs/skills-format.md` says to replace with a fixed artifact. The
unstacked-pull-request failure this whole skill exists to prevent was a briefing
failure.

**TDD linkage is absent.** The task document's contract table commits the loop to
`skills/tdd` for the implementer's middle phase. The shipped skill never mentions
it, so "the conventions to load" silently drops the one convention the design
named.

### 6. Token Efficiency — 2 (ratio 0.919)

620 lines, roughly 50 removable without losing a rule:

| Source | Est. lines |
|---|---:|
| `commands/story-loop.md` restating three rules that belong in `SKILL.md` | 13 |
| Depth cap and one-iteration rules stated three times | 8 |
| `SKILL.md` steps 2 and 6 duplicating `orchestrator.md` | 6 |
| `chain.md` narrative compressible without losing the argument | 15 |
| Runner files repeating "still validate against the return template" | 4 |
| Approximate removable | 46 |

574 / 620 = 0.919. Above the 0.90 threshold, but the headroom comes from the
artifact being new and small. Every line of the 46 is redundancy already counted in
dimension 3, so fixing that dimension fixes this one.

## Validity Findings

Separate from the rubric, which rewards a specific directive even when it is wrong
or unproven.

### High: the shipped artifact does not carry its own decisions

OD-1 (bounded remediation supersedes reviewer segregation) and the standing
authorization grant were both settled in
`tasks/2026-09-09-story-loop-command.md` and both produce cross-file conflicts
because neither was written into the skill. `tasks/` is gitignored, so the decision
record does not travel with the skill on deployment. A `## Precedence` section in
`SKILL.md`, naming `commands/git.md` and `INSTRUCTIONS.md` explicitly and stating
what this skill overrides and within what bounds, closes both conflicts.

### High: eleven acceptance criteria are unverified, and the untested half is the LLM half

`selftest.sh` (30/30) and `e2e-chain.sh` (10/10) cover the deterministic layer:
chain head, eligibility, stalled detection, parent computation, base checking,
cold-start resume, and a real 3-deep git stack confirmed with
`git merge-base --is-ancestor`. Deployment to all three tools was verified against a
sandboxed `HOME`.

Nothing exercises the implementer brief, the return-contract rejection path,
remediation rounds, verifier independence, or the context budget. The evidence is
genuine and it is evidence about the floor of the system, not its behaviour.

### Medium: `SKILL.md` is at its size ceiling

Exactly 100 lines against a 100-line cap. The precedence section recommended above
does not fit without removing something first, and the natural candidates are the
six duplicated concepts identified in dimension 3.

### Low: one unverifiable budget

"Under 10% of the window" has no measurement procedure. Either name a proxy an
agent can actually check, such as a cap on story bodies opened (zero) and verdict
files opened (zero), or state it as a design intent rather than a rule.

## Context: other evaluations in this repository

Different scopes, not a progression.

| Evaluation | Scope | Composite |
|---|---|---:|
| 2026-08-31 corpus | Full repository | 1.13 |
| 2026-09-08 corpus | Full repository | 0.50 |
| 2026-09-08 pr-judge | Single agent file | 1.55 |
| **2026-09-09 story-loop** | **Nine-file skill** | **1.20** |

The full-corpus figures are depressed by historical records under `docs/` that this
scope excludes, so the meaningful comparison is against the pr-judge evaluation,
the only other single-artifact score. story-loop lands 0.35 below it. The gap is
entirely redundancy (0 versus pr-judge's 2) and density (1 versus 2); story-loop is
ahead on efficiency and level on specificity.

That shape is diagnostic. A nine-file skill has cross-file duplication available to
it that a one-file agent definition does not. The multi-file structure bought host
portability and paid for it in restatement.

## Recommended Remediation, In Order

1. **Reduce `commands/story-loop.md` to a real dispatcher.** Load the skill, name
   the two failure modes in one line each, link. Removes 13 lines and three of the
   six redundancies. Satisfies its own acceptance criterion, which it currently
   fails.
2. **Add a `## Precedence` section to `SKILL.md`**, stating what this skill
   overrides in `commands/git.md` and `INSTRUCTIONS.md` and within what bounds.
   Resolves both scored contradictions. Requires step 1 for space.
3. **Add `implementer-brief.md`**, a fixed template with the four briefing slots
   filled in, naming `skills/tdd` and `skills/git-conventions` explicitly as the
   conventions to load. Closes the largest coverage gap and the largest specificity
   weakness in one file.
4. **Deduplicate the depth cap and the one-iteration rule** to one canonical home
   each, leaving links.
5. **Replace the 10% budget** with a countable proxy.

Items 1 through 3 would move redundancy from 0 to 1, coverage from 1 to 2, and
contradictions from 1 to 2, for a composite of roughly 1.60 without touching a
single script.

---

# Addendum: Post-Remediation Re-Score — 2026-09-09

All five recommended items applied, plus one added during the work. Re-scored
against the same rubric and method.

```text
╔══════════════════════════════════════════════════════════════╗
║  STORY-LOOP RE-SCORE — 2026-09-09 (after remediation)        ║
╠══════════════════════════════════════════════════════════════╣
║  RAW METRICS                                                ║
║  Files: 10 |  Lines: 708 |  Files >100 lines: 2             ║
╠══════════════════════════════════════════════════════════════╣
║  Directive Density    1  (weight 20%)  ratio 0.615          ║
║  Contradiction Count  2  (weight 20%)  0 conflicts           ║
║  Redundancy Index     1  (weight 15%)  ratio 0.105          ║
║  Specificity Score    2  (weight 20%)  average 1.95          ║
║  Coverage Complete    2  (weight 10%)  ratio 0.867           ║
║  Token Efficiency     2  (weight 15%)  ratio 0.958           ║
║                                                             ║
║  COMPOSITE: 1.65 / 2.00  →  EFFECTIVE                       ║
╚══════════════════════════════════════════════════════════════╝
```

## Delta

| Dimension | Before | After | Change |
|---|---:|---:|---|
| Directive Density | 1 (0.599) | 1 (0.615) | Marginal; `chain.md` still governs |
| Contradiction Count | 1 (2 conflicts) | **2** (0) | `## Precedence` resolves both |
| Redundancy Index | 0 (0.333) | **1** (0.105) | 6 duplications down to 2 boundary cases |
| Specificity Score | 2 (1.85) | 2 (1.95) | Two of three weak directives fixed |
| Coverage Completeness | 1 (0.667) | **2** (0.867) | Brief, TDD linkage, state-move mapping |
| Token Efficiency | 2 (0.919) | 2 (0.958) | Duplication removed; brief added is all payload |
| **Composite** | **1.20** | **1.65** | **+0.45, NEEDS WORK to EFFECTIVE** |

## What changed

1. **`commands/story-loop.md` reduced to a dispatcher**, 31 lines to 23. It no
   longer restates the authorization boundary, the read-nothing rule or the `BASE`
   check. It now satisfies its own acceptance criterion, which it previously failed
   while the criterion was ticked.

2. **`## Precedence` added to `SKILL.md`.** A two-row table stating exactly what
   this skill narrows in `INSTRUCTIONS.md` and `commands/git.md`, bounded to one
   iteration, with an explicit default: "If unsure whether an action is inside a
   narrowing, it is not." Both scored contradictions are resolved at the source
   rather than left to an agent's judgement. The decisions from
   `tasks/2026-09-09-story-loop-command.md` now travel with the deployed skill,
   which matters because `tasks/` is gitignored.

3. **`implementer-brief.md` added**, 78 lines. A literal send-as-is template with
   five filled slots, the branch-from-parent and `--base` commands inline, the
   authorization grant restated in the second person for the subagent, and the
   return contract. A slot-rules table names the failure each wrong slot causes.
   `skills/tdd` and `skills/git-conventions` are now named explicitly, replacing
   the vague "the conventions to load."

4. **Duplication resolved to canonical homes.** The return contract moved out of
   `orchestrator.md` into `implementer-brief.md`, which must carry it verbatim
   anyway; `orchestrator.md` now states only what it validates on receipt. The
   depth cap and the one-iteration rule each have one explanatory home with
   references elsewhere.

5. **The 10% context budget replaced with a countable proxy.** Story bodies opened,
   zero. Verdict files opened, zero. Diffs read, zero. Test output read, zero.
   Countable during a run, unlike a share of the context window.

6. **Added during remediation, not in the original list: the outcome-to-folder
   mapping.** `landed` and `partial` to `4_in-review`, `blocked` to `5_blocked`,
   `6_completed` never written because this loop never merges, and the file moves
   *after* the implementer returns so a crashed subagent cannot strand a story
   outside both the queue and the log. "Per the state machine" was not actionable;
   this was the third partial coverage domain and the cheapest to close.

## Verification after remediation

| Check | Result |
|---|---|
| `selftest.sh` | 30/30 |
| `e2e-chain.sh` | 10/10 |
| Authorization boundary, task doc vs `SKILL.md` | verbatim match |
| `SKILL.md` against the 100-line cap | 99 |
| Deploy to all three tools, sandboxed `HOME` | 9 Markdown files each, brief present |
| Harnesses from the deployed copy | 30/30, 10/10 |
| Real `HOME` | untouched |

No script changed, so the passing harnesses confirm the remediation was
documentation-only and broke nothing.

## What remains, and why

**Directive density stays at 1 (0.615).** `chain.md` is still the floor at roughly
0.32: forty-eight of its seventy-one content lines argue for the rule rather than
state it. That is deliberate and it is not going to be fixed. The narrative is why
a future editor will not "simplify" the parent computation back into a default, and
the unstacked-pull-request failure is the proof that the rule does not survive on
its own. Raising this dimension to 2 means deleting the argument, which trades a
metric for the thing the metric is supposed to protect.

**Coverage is 2 but two partials remain.** Forge abstraction is `gh`-shaped plus
`none`, with no Azure DevOps path despite two ADO skills in this workspace. Crash
recovery names worktree pruning only in `runner-codex.md`. Both are real and
neither blocks a first run.

**Eleven acceptance criteria are still unverified**, unchanged by this remediation,
because they all require spawning subagents. The deterministic layer is tested; the
LLM layer is not. `implementer-brief.md` makes that layer testable for the first
time by giving it a fixed artifact to test against, but no test has been run.
