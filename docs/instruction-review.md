# Instruction Review: Effectiveness & Recommendations

**Date:** 2026-03-13
**Scope:** Historical review of files in `skills/` before the skill-directory migration.

---

## Executive Summary

The `skills` repository is a well-structured set of AI behavior rules and on-demand skills for a cloud engineering team. The core ideas — persistent context via brain dumps, git safety lockdown, and codified Terraform patterns — are sound and practical.

However, the instruction set suffers from **redundancy across files**, **contradictory directives**, and **overspecification of personality** that dilute the actionable technical content. Approximately 30-40% of the total content is duplicated or could be consolidated without losing meaning.

---

## File-by-File Assessment

### 1. INSTRUCTIONS.md (157 lines)

**Effectiveness: Medium**

**Strengths:**
- Git lockdown rules are clear, exhaustive, and well-formatted with checkmark/cross icons
- The required workflow for code changes (make changes → diff → present → wait) is unambiguous
- Brain dump protocol provides a concrete, repeatable process

**Issues:**
- **"Robot Behavior" section contradicts itself.** It says "No first person opinions" but also "Make decisions, don't ask for permission." These are tension points that will produce inconsistent behavior across models and sessions.
- **Personality directives are excessive.** "BEEP BOOP. TASK INITIATED." and "Draw 80s-style computer graphics" consume instruction tokens for novelty rather than utility. LLMs will spend tokens roleplaying instead of solving problems.
- **"READ AND WAIT" in the title is unclear.** Wait for what? The file doesn't explain what the agent should wait for after reading.
- **TDD emoji icons (lines 67)** are referenced but never used in INSTRUCTIONS.md itself. They appear in `testing.md` inconsistently. The directive is orphaned.
- **Repository Context Protocol (lines 9-18)** asks the agent to run `pwd` and state the repository name — most AI tools already know the working directory. This is 10 lines of ceremony that adds little value.
- **Brain Dump Protocol overlaps heavily** with `docs/task-management.md`. The same workflow is described in two places with slightly different terminology.

**Recommendations:**
1. Remove or drastically shorten the "Robot Behavior" section. A single line like "Communicate tersely. No filler, praise, or enthusiasm. State actions before and after executing." achieves the same effect without the BEEP BOOP roleplay.
2. Remove the Repository Context Protocol. The agent already knows `pwd`.
3. Consolidate brain dump instructions into one location (either INSTRUCTIONS.md or `docs/task-management.md`, not both).
4. Resolve the "don't ask permission" vs. "wait for approval" contradiction. Pick one stance per operation type.

---

### 2. README.md (126 lines)

**Effectiveness: High**

**Strengths:**
- Clear repository structure diagram
- Good quick-start instructions for multiple AI tools
- Accurate summary of what each component does

**Issues:**
- **Duplicates content from INSTRUCTIONS.md and docs/.** The "Key Features" section (lines 72-96) restates the git lockdown, robot mode, and brain dump workflow already documented elsewhere.
- **Usage example (lines 107-121)** shows an idealized interaction that doesn't match the actual startup template behavior.

**Recommendations:**
1. Keep README.md as the index/navigation file. Remove the "Key Features" section and replace with links to the source files.
2. Verify the usage example matches actual behavior.

---

### 3. docs/getting-started.md (77 lines)

**Effectiveness: Low-Medium**

**Issues:**
- **Almost entirely duplicates README.md.** The setup instructions, tool configuration, and "What Gets Loaded" sections are restated from README.md with minor wording changes.
- **"First Use" section (lines 64-71)** is useful but could live in README.md.

**Recommendations:**
1. **Consider removing this file entirely.** Its content is covered by README.md. If kept, it should contain only information not in README.md — e.g., troubleshooting, common mistakes, or advanced configuration.

---

### 4. docs/startup-template.md (16 lines)

**Effectiveness: High**

**Strengths:**
- Short, focused, actionable
- Clear priority order for task files
- Appropriate fallback behavior ("ask the user for help")

**Issues:**
- Minor: The last two lines ("If you are not sure what to do" / "If you are not sure how to do something") are near-duplicates. One line covering both cases would suffice.

**Recommendations:**
1. Merge the two "if unsure" lines into: "If unclear on what to do or how to proceed, ask the user."

---

### 5. docs/task-management.md (180 lines)

**Effectiveness: Medium-High**

**Strengths:**
- The "Context Problem" framing is excellent — it explains *why* the workflow exists
- The Spacelift migration example (lines 110-131) is concrete and helpful
- "Why This Works" section (lines 133-147) provides good rationale

**Issues:**
- **Significant overlap with INSTRUCTIONS.md** brain dump protocol. Same workflow described in different words.
- **File naming is inconsistent.** References `CONTEXT.md`, `main.md`, `OVERVIEW.md`, `CURRENT.md`, `TASKS.md` as valid brain dump filenames. This flexibility creates confusion — an agent doesn't know which to look for first. The startup template specifies a priority order, but this file doesn't reference it.
- **Example structures are verbose.** The markdown template example (lines 37-58) and the multiple task creation examples (lines 65-83) could be shorter.

**Recommendations:**
1. Standardize on one or two canonical filenames (e.g., `CONTEXT.md` for project context, `tasks/CURRENT.md` for active tasks). Document the priority order once, in one place.
2. Remove the brain dump protocol from INSTRUCTIONS.md and keep it only here, with a link from INSTRUCTIONS.md.
3. Shorten the example structures.

---

### 6. rules/README.md (28 lines)

**Effectiveness: High**

Clean index file. No issues.

---

### 7. skills/git-conventions/README.md (26 lines)

**Effectiveness: High**

**Strengths:**
- The distinction between INSTRUCTIONS.md (enforcement) and git-conventions skill guidance is valuable and well-stated.

No significant issues.

---

### 8. skills/git-conventions/branching.md (24 lines)

**Effectiveness: High**

Concise, clear naming convention with good examples. Model document for what skill references should look like.

---

### 9. skills/git-conventions/commits.md (29 lines)

**Effectiveness: High**

Good/bad examples are effective. Concise.

---

### 10. skills/git-conventions/workflows.md (5 lines)

**Effectiveness: Low**

**Issues:**
- **Only one sentence.** "All code changes require pull requests for review and approval before merging." This is too thin to be a standalone file. It provides no guidance on PR descriptions, review criteria, merge strategies, or branch protection.

**Recommendations:**
1. Either expand this file with meaningful PR workflow content or merge the one-line rule into `branching.md` or `commits.md` and delete this file.

---

### 11. skills/terraform/README.md (23 lines)

**Effectiveness: High**

Good index with useful terminology definitions. The "Platform" section clearly establishing OpenTofu preference is valuable.

---

### 12. skills/terraform/structure.md (107 lines)

**Effectiveness: High**

**Strengths:**
- Clear directory layout diagrams
- The file ordering rationale (locals → top-level → dependent → modules) is well-explained with a concrete HCL example
- Design principles section is a good checklist

No significant issues. This is one of the strongest files in the repository.

---

### 13. skills/terraform/testing.md (395 lines)

**Effectiveness: Medium-High**

**Strengths:**
- Comprehensive test patterns with real HCL examples
- Good segregation of plan vs. apply tests
- Helper module pattern is practical and well-documented
- TDD-inspired section provides clear philosophy

**Issues:**
- **Longest file in the repo by far** (395 lines vs. next longest at 180). The extensive HCL examples are useful but make this feel more like a tutorial than a reference document.
- **Some examples are repetitive.** The storage account naming validation is tested in at least 4 different example blocks across the file with minor variations. One comprehensive example would suffice.
- **CI integration section (lines 380-389)** is only 8 lines — this is the most operationally important part and deserves more detail (e.g., pipeline configuration, environment variables, failure handling).

**Recommendations:**
1. Reduce redundant storage account examples. Use one "complete test file" example that demonstrates all patterns, rather than repeating similar blocks.
2. Expand the CI integration section.
3. Consider splitting into `testing-patterns.md` (philosophy + patterns) and `testing-examples.md` (full HCL examples) if length remains high.

---

### 14. skills/terraform/style.md (164 lines)

**Effectiveness: High**

**Strengths:**
- Variable declaration requirements are clear and well-graduated (required → strongly encouraged → optional)
- Fail-fast pattern is well-explained
- Formatting rules are concise

**Minor Issues:**
- The commented-out location validation (lines 50-55) is a nice idea but could confuse an LLM into thinking it should uncomment it.

---

## Cross-Cutting Issues

### 1. Redundancy Map

The following concepts are explained in multiple files:

| Concept | Locations | Recommendation |
|---|---|---|
| Brain dump workflow | INSTRUCTIONS.md, task-management.md, README.md | Keep in task-management.md only; link from others |
| Git lockdown rules | INSTRUCTIONS.md, README.md, git/README.md | Keep in INSTRUCTIONS.md only; summarize in README.md |
| Setup/quick start | README.md, getting-started.md | Keep in README.md; remove or repurpose getting-started.md |
| Robot personality | INSTRUCTIONS.md, README.md | Keep in INSTRUCTIONS.md only |
| File naming for brain dumps | INSTRUCTIONS.md, task-management.md, startup-template.md | Standardize in one location |

### 2. Token Budget Efficiency

These instructions are consumed by LLMs with finite context windows. Every line of personality roleplay ("BEEP BOOP BOP"), duplicated content, or ceremony (Repository Context Protocol) costs tokens that could be used for actual code reasoning. Rough estimate: **200-300 lines (~20-25%) could be removed** without losing any functional guidance.

### 3. Contradictions

| Directive A | Directive B | Location |
|---|---|---|
| "Make decisions, don't ask for permission" | "Wait for approval before implementation begins" | INSTRUCTIONS.md lines 63, 37 |
| "No first person opinions" | "When making recommendations provide multiple options" (requires judgment) | INSTRUCTIONS.md lines 62-63 |
| "BEEP BOOP" robot persona | "No filler words or pleasantries" | INSTRUCTIONS.md lines 58, 65 |

### 4. Missing Content

- **No Python/general programming skills.** If the team writes Python, there are no patterns for it.
- **No secret management guidance.** The git lockdown prevents committing secrets, but there's no guidance on *how* to handle secrets (vault references, environment variables, etc.).
- **No error handling patterns** for Terraform (e.g., `precondition`/`postcondition` blocks, `check` blocks).
- **workflows.md is essentially empty.** PR workflow is a critical topic with no real guidance.

---

## Summary of Recommendations

### High Priority (Immediate Value)

1. **Consolidate brain dump instructions** into `docs/task-management.md` only. Replace content in INSTRUCTIONS.md with a one-line link.
2. **Remove or merge `docs/getting-started.md`** into README.md. It's nearly 100% duplicate content.
3. **Simplify the "Robot Behavior" section** to 2-3 actionable lines. Drop BEEP BOOP, 80s graphics, and emoji directives.
4. **Resolve contradictions** between "make decisions" and "wait for approval." Define which actions require approval (git, architecture) and which don't (code formatting, test execution).
5. **Standardize brain dump filenames.** Pick a canonical name and document the priority order in one place.

### Medium Priority (Quality Improvement)

6. **Expand `workflows.md`** with real PR workflow content or merge into another file.
7. **Reduce redundant HCL examples in `testing.md`** — consolidate the 4+ storage account naming examples into one comprehensive block.
8. **Remove the Repository Context Protocol** from INSTRUCTIONS.md. It adds ceremony without value.
9. **Expand CI integration section** in `testing.md`.

### Low Priority (Future Enhancement)

10. **Add Python/scripting skills** if the team writes automation code.
11. **Add secret management guidance** (vault patterns, environment variable conventions).
12. **Add Terraform error handling patterns** (precondition/postcondition, check blocks).
13. **Add a `CHANGELOG.md`** to track skill evolution.

---

## Metrics

| Metric | Current | Target |
|---|---|---|
| Total files | 14 | 11-12 |
| Total lines | ~1,210 | ~850-900 |
| Duplicated concepts | 5 major | 0 |
| Contradictions | 3 | 0 |
| Empty/stub files | 1 (workflows.md) | 0 |
| Avg lines per skill reference | ~86 | ~70 |
