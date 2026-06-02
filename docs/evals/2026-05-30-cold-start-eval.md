# Cold-Start Protocol Evaluation -- 2026-05-30

**Scope:** 9 files comprising the cold-start protocol subsystem (286 total lines)

```
docs/cold-start-protocol.md        50 lines
skills/cold-start/SKILL.md         33 lines
skills/cold-start/checklist.md     45 lines
skills/cold-start/templates/       70 lines (3 files)
commands/cs-init.md                28 lines
commands/cs-work.md                28 lines
commands/cs-decide.md              32 lines
```

---

## Raw Metrics

- Files: 9
- Total lines: 286
- Files > 100 lines: 0
- Average file length: 32 lines

---

## Dimension Scores

### 1. Directive Density

**Method:** Counted non-blank, non-heading content lines across all 9 files. Counted lines containing actionable directives (DO/DO NOT behavior).

- Total content lines: ~164
- Directive lines: ~97
- Ratio: 0.59

Templates pull the ratio down (scaffolding, not directives). Excluding templates: 89/129 = 0.69. Commands and checklist are very high-density (0.77-0.83).

**Score: 1** (0.40-0.70 range)

---

### 2. Contradiction Count

**Contradictions found: 1**

| Directive A | Directive B | Tension |
|-------------|-------------|---------|
| Protocol table: CONTEXT.md role is "Immutable project substrate" | Write order: "CONTEXT.md -- update only if project scope shifted" | "Immutable" vs. "update rarely" is a terminology contradiction. The qualifier "(rare, flag for user review)" softens it, but the word "immutable" is technically inaccurate. |

No other contradictions. The read/write checklists, commands, and protocol all agree on sequence, file names, failure modes, and rotation rules.

**Score: 1** (1 contradiction -- agent can reasonably resolve since "immutable" is qualified)

**Fix:** Replace "Immutable project substrate" with "Stable project substrate" or "Rarely-changing project substrate" in the protocol table.

---

### 3. Redundancy Index

**Concepts identified:** 9
1. Three-file contract
2. Read order (sequence of 3 files)
3. Write order (sequence of 3 files)
4. Rotation rules (100/200 line limits)
5. Cold-start premise (ephemeral sessions)
6. Failure modes (missing files)
7. File templates/shapes
8. Anti-patterns
9. Compatibility with existing workflow

**Concepts re-explained in 2+ files:**

| Concept | Files | Assessment |
|---------|-------|------------|
| Read order | protocol, checklist, cs-work, cs-decide | Commands reference checklist AND inline abbreviated steps. Intentional for cold-start self-sufficiency. |
| Write order | protocol, checklist, cs-work | Same pattern. Commands abbreviate but repeat. |
| Failure modes | checklist, cs-work, cs-decide, cs-init | Commands give one-liners; checklist has full detail. Light duplication. |

- Concepts with material re-explanation: 3/9 = 0.33
- Mitigating factor: commands reference the canonical source ("Run the read checklist from skills/cold-start/checklist.md") and only inline abbreviated summaries. This is by design -- cold-start files should be independently executable.

**Score: 0** (> 0.25 ratio, even accounting for intentional design)

**Note:** This is the hardest dimension for the cold-start pattern. The protocol's core premise -- every file must be self-sufficient for a cold reader -- inherently creates repetition. This is a known cost acknowledged in the design doc. The question is whether the commands should drop inline steps entirely and rely solely on the checklist reference.

---

### 4. Specificity Score

**20-directive sample:**

| # | Directive | Rating |
|---|-----------|--------|
| 1 | "Cold start every command, read markdown as persistent state, do work, write state back, exit clean" | 2 |
| 2 | "Read CONTEXT.md in the project root -- restore project substrate" | 2 |
| 3 | "Read tasks/DECISIONS.md -- restore decision history" | 2 |
| 4 | "Confirm: 'Cold start complete. Loaded N lines from M files.'" | 2 |
| 5 | "CONTEXT.md missing: prompt user to run /cs-init before continuing" | 2 |
| 6 | "tasks/DECISIONS.md missing: create it from template, log that it was created" | 2 |
| 7 | "Mark completed checkboxes [x]" | 2 |
| 8 | "Update **Next:** to the single most concrete next action" | 1 |
| 9 | "If tasks/CURRENT.md exceeds 100 lines: move completed items to tasks/archive/" | 2 |
| 10 | "Move entries older than 30 days to tasks/DECISIONS-archive.md" | 2 |
| 11 | "Every invocation is a cold start. No exceptions." | 2 |
| 12 | "If it is not in a file, it does not exist." | 2 |
| 13 | "Read before work. Write before exit. Always." | 2 |
| 14 | "Keep CURRENT.md under 100 lines. Rotate aggressively." | 1 |
| 15 | "Check if files already exist. If any do, ask the user before overwriting." | 2 |
| 16 | "Ask: 'What is this project? (1-2 sentences)'" | 2 |
| 17 | "Make no assumptions about prior conversation." | 2 |
| 18 | "Do not proceed until the user selects an option." | 2 |
| 19 | "Append: \| YYYY-MM-DD \| [chosen option] \| [rationale] \|" | 2 |
| 20 | "The decision is logged before any implementation begins." | 2 |

- Scores: 18x2 + 2x1 = 38/40
- Average: 1.90

**Score: 2** (> 1.5 average)

The two "mostly specific" items: "most concrete next action" (what counts as concrete?) and "rotate aggressively" (what threshold beyond 100 lines?). Both are minor -- the rules around them provide sufficient constraint.

---

### 5. Coverage Completeness

**Domains the cold-start protocol should cover:**

| Domain | Covered? | File |
|--------|----------|------|
| Session initialization | Yes | cs-init.md |
| Work execution loop | Yes | cs-work.md |
| Decision-making | Yes | cs-decide.md |
| State read protocol | Yes | checklist.md |
| State write protocol | Yes | checklist.md |
| Rotation/archival | Yes | protocol + checklist |
| Error handling (missing files) | Yes | checklist + commands |
| Template/file structure | Yes | templates/ |
| Integration with /startup | Yes | protocol compatibility section |
| Exit/reporting | Yes | commands (step 5/7) |
| Multi-user scenarios | No | -- |
| Merge conflicts in state files | No | -- |
| Migration from /startup to cold-start | No | -- |
| CONTEXT.md growth management | Partial | "No hard limit" stated but no guidance if it grows unwieldy |

- Covered: 10/14 = 0.71

**Score: 1** (0.50-0.80 range)

**Gaps to address:**
- Multi-user: what happens if two people run /cs-work on the same project concurrently?
- Merge conflicts: git-tracked state files will conflict. No guidance on resolution.
- Migration: no explicit path from /startup to cold-start for existing projects.

---

### 6. Token Efficiency

- Total lines: 286
- Estimated removable lines:
  - Redundant read-order steps in commands (already reference checklist): ~12 lines
  - Template HTML comments that restate protocol rules: ~5 lines
  - Could merge cs-work failure mode into checklist (already there): ~3 lines
- Removable: ~20 lines
- Efficiency: (286 - 20) / 286 = 0.93

**Score: 2** (> 0.90 -- lean, almost everything earns its place)

---

## Composite Score

```
composite = (density * 0.20) + (contradictions * 0.20) + (redundancy * 0.15)
          + (specificity * 0.20) + (coverage * 0.10) + (efficiency * 0.15)

          = (1 * 0.20) + (1 * 0.20) + (0 * 0.15)
          + (2 * 0.20) + (1 * 0.10) + (2 * 0.15)

          = 0.20 + 0.20 + 0.00 + 0.40 + 0.10 + 0.30

          = 1.20
```

---

```
╔══════════════════════════════════════════════════════════════╗
║  COLD-START PROTOCOL EVALUATION -- 2026-05-30               ║
╠══════════════════════════════════════════════════════════════╣
║  RAW METRICS                                                ║
║  Files: 9  |  Lines: 286  |  Files >100 lines: 0           ║
╠══════════════════════════════════════════════════════════════╣
║  DIMENSION SCORES                                           ║
║                                                             ║
║  Directive Density    1  (weight 20%)  ratio 0.59           ║
║  Contradiction Count  1  (weight 20%)  1 terminology issue  ║
║  Redundancy Index     0  (weight 15%)  0.33 ratio           ║
║  Specificity Score    2  (weight 20%)  avg 1.90             ║
║  Coverage Complete    1  (weight 10%)  0.71 coverage        ║
║  Token Efficiency     2  (weight 15%)  0.93 ratio           ║
║                                                             ║
║  COMPOSITE: 1.20 / 2.00  ->  NEEDS IMPROVEMENT             ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 ISSUES                                               ║
║  1. Redundancy: read/write order repeated in protocol,      ║
║     checklist, AND commands (0.33 ratio)                    ║
║  2. Contradiction: "Immutable" label vs. qualified write    ║
║     path for CONTEXT.md                                     ║
║  3. Coverage gaps: no multi-user, merge conflict, or        ║
║     migration guidance                                      ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 IMPROVEMENTS SINCE LAST EVAL                         ║
║  1. N/A -- first eval of cold-start subsystem               ║
║  2.                                                         ║
║  3.                                                         ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Recommendations

### Quick wins (would move composite to ~1.55):

1. **Fix the contradiction (Score 1 -> 2, +0.20):** Replace "Immutable project substrate" with "Stable project substrate" in the protocol table. One word change.

2. **Reduce command redundancy (Score 0 -> 1, +0.15):** Remove inline read/write steps from commands; rely solely on "Run the read checklist from skills/cold-start/checklist.md" without re-listing the steps. This trades self-sufficiency for token efficiency. The checklist is always loaded via the skill anyway.

### Longer-term:

3. **Add coverage for gaps:** A short "Edge Cases" section in checklist.md addressing concurrent users and merge conflicts (~5 lines). Add a "Migration" note to cs-init.md for projects already using /startup.

4. **Templates are density drag:** They're correct as-is (scaffolding should not be directives). Accept that they pull density down, or exclude them from future evals since they're output artifacts, not instruction text.
