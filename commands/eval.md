---
description: Score the instruction set across 6 dimensions (density, contradictions, redundancy, specificity, coverage, token efficiency) and save a dated report to docs/evals/
---

# Evaluation: skills Document Quality

## Step 1: Collect Raw Metrics

Run these commands and capture output:

```bash
# File count (excluding tasks/ and .git/)
find ~/repos/skills -type f -name "*.md" ! -path "*/tasks/*" ! -path "*/.git/*" | wc -l

# Total lines
find ~/repos/skills -type f -name "*.md" ! -path "*/tasks/*" ! -path "*/.git/*" | xargs wc -l

# Files exceeding 100-line target
find ~/repos/skills -type f -name "*.md" ! -path "*/tasks/*" ! -path "*/.git/*" -exec sh -c 'lines=$(wc -l < "$1"); if [ "$lines" -gt 100 ]; then echo "$lines $1"; fi' _ {} \; | sort -rn
```

## Step 2: Read All Instruction Files

Read every .md file in these directories (excluding tasks/):
- `~/repos/skills/INSTRUCTIONS.md`
- `~/repos/skills/README.md`
- `~/repos/skills/docs/` (all .md files)
- `~/repos/skills/rules/` (all .md files, recursively)

## Step 3: Score 6 Dimensions

Using the rubric from `~/repos/skills/docs/evaluation-framework.md`, Part 1, score each dimension 0-2:

### 3a. Directive Density (weight: 20%)
- Count non-blank, non-heading content lines across all files
- Count lines that are actionable directives (DO or DO NOT)
- Calculate ratio. Score: >0.70=2, 0.40-0.70=1, <0.40=0

### 3b. Contradiction Count (weight: 20%)
- Extract all directives, group by topic
- Identify directive pairs where following A conflicts with B
- Score: 0 contradictions=2, 1-2=1, 3+=0

### 3c. Redundancy Index (weight: 15%)
- Identify every distinct concept/workflow described
- Count concepts fully re-explained in 2+ files (not just referenced)
- Calculate ratio. Score: <0.10=2, 0.10-0.25=1, >0.25=0

### 3d. Specificity Score (weight: 20%)
- Sample 20 directives across files
- Rate each: specific (2), mostly specific (1), vague (0)
- Average. Score: >1.5=2, 1.0-1.5=1, <1.0=0

### 3e. Coverage Completeness (weight: 10%)
- List all domains/technologies the team works with
- Check if each has skill coverage
- Calculate ratio. Score: >0.80=2, 0.50-0.80=1, <0.50=0

### 3f. Token Efficiency (weight: 15%)
- Total lines in all instruction files
- Estimate removable lines (redundant, filler, ceremony, orphaned)
- Calculate efficiency ratio. Score: >0.90=2, 0.75-0.90=1, <0.75=0

## Step 4: Calculate Composite Score

```
composite = (density * 0.20) + (contradictions * 0.20) + (redundancy * 0.15)
          + (specificity * 0.20) + (coverage * 0.10) + (efficiency * 0.15)
```

Interpretation: 1.6-2.0 effective, 1.0-1.5 needs improvement, <1.0 significant problems.

## Step 5: Output Report

Print report in this exact format:

```
╔══════════════════════════════════════════════════════════════╗
║  SKILLS EVALUATION — [date]                                  ║
╠══════════════════════════════════════════════════════════════╣
║  RAW METRICS                                                ║
║  Files: [n]  |  Lines: [n]  |  Files >100 lines: [n]       ║
╠══════════════════════════════════════════════════════════════╣
║  DIMENSION SCORES                                           ║
║                                                             ║
║  Directive Density    [0-2]  (weight 20%)  [notes]          ║
║  Contradiction Count  [0-2]  (weight 20%)  [notes]          ║
║  Redundancy Index     [0-2]  (weight 15%)  [notes]          ║
║  Specificity Score    [0-2]  (weight 20%)  [notes]          ║
║  Coverage Complete    [0-2]  (weight 10%)  [notes]          ║
║  Token Efficiency     [0-2]  (weight 15%)  [notes]          ║
║                                                             ║
║  COMPOSITE: [X.XX / 2.00]  →  [EFFECTIVE/NEEDS WORK/POOR]  ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 ISSUES                                               ║
║  1. [issue]                                                 ║
║  2. [issue]                                                 ║
║  3. [issue]                                                 ║
╠══════════════════════════════════════════════════════════════╣
║  TOP 3 IMPROVEMENTS SINCE LAST EVAL                         ║
║  (compare to previous eval in docs/evals/ if one exists)    ║
║  1. [improvement or "N/A — first eval"]                     ║
║  2. [improvement or ""]                                     ║
║  3. [improvement or ""]                                     ║
╚══════════════════════════════════════════════════════════════╝
```

## Step 6: Store Results

Save the full scored report (including per-dimension reasoning, not just the summary box) to:
```
~/repos/skills/docs/evals/[YYYY-MM-DD]-eval.md
```

Create the `docs/evals/` directory if it doesn't exist.

If a previous eval exists in `docs/evals/`, include a before/after delta table comparing to the most recent one.
