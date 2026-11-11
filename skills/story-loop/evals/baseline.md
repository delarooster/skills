# story-loop: eval 2026-10-27

Composite **0.95 / 2.0** (significant problems). Model `gpt-6.1-sol`. Rubric: `/eval` Part 1, scoped to skill Markdown only; scripts and metadata are not scored.

## Baseline

| Metric | Value |
|---|---|
| Markdown files | 12 |
| Total lines | 1553 |
| SKILL.md lines | 167 |
| Files over 100 lines | SKILL.md, adapter.md, chain.md, implementer-brief.md, orchestrator.md, runner-codex.md, verify.md |

## Scores

| Dimension | Weight | Score | Evidence |
|---|---|---|---|
| Directive density | 20% | 1 | Across 12 Markdown files, an estimated 910 of 1,450 nonblank, nonheading content lines contain directives or supporting operational examples, approximately 63%. Extended rationale, navigation, and repeated explanations dilute otherwise actionable guidance. |
| Contradictions | 20% | 0 | There are 5 conflicting directive pairs: implementer merge authorization, phase-2 CI waiting, pre-return story moves, verification versus base-check ordering, and branch creation ownership between runners and the brief. |
| Redundancy | 15% | 0 | Approximately 14 of 32 distinct concepts are re-explained in multiple files, a redundancy index of 44%. Repeated concepts include authorization, parent selection, isolation, fresh verification, warm remediation, closeout, CI pacing, and scoped checks. |
| Specificity | 20% | 2 | A sample of 20 directives contains 17 specific and 3 mostly specific directives, averaging 1.85/2. Commands, return fields, routing thresholds, folder mappings, and remediation limits are generally concrete and testable. |
| Coverage | 10% | 2 | The body covers all 6 description promises: eligible-story selection, fresh implementation context, stacked pull-request creation, verifier dispatch, result logging, and host-controlled repetition. Coverage is 6/6, with branch-only operation explicitly documented as the compatibility exception. |
| Token efficiency | 15% | 1 | Of approximately 1,750 total lines, about 300 could be removed through consolidation of repeated rules, rationale, and workflow summaries, yielding roughly 83% efficiency. The fixed templates and host-specific commands provide substantial value despite this duplication. |

## Findings

- **high** `teams.md`: Teams require implementers to merge an updated parent or base into their own branches, but SKILL.md forbids any other merge and implementer-brief.md explicitly prohibits implementer merges. The phase-2 exception therefore lacks a consistent top-level authorization. Fix: Add a narrowly scoped authorization in SKILL.md and the implementer brief for merging the declared parent or base into the implementer's own story branch during team synchronization; continue prohibiting all other implementer merges.
- **medium** `runner-codex.md`: The manual runner creates the story branch with git worktree add -b, while the fixed brief subsequently requires git switch -c for that same branch. The existing-branch exception only covers branches already on the remote, not the newly created local branch; runner-opencode.md repeats this collision. Fix: Have manual runners create a detached worktree at the computed parent and let the implementer create the branch, or add an explicit brief variant that validates and uses a runner-created local branch.
- **medium** `orchestrator.md`: The numbered workflow dispatches the verifier in step 4 and checks BASE in step 5, whereas SKILL.md requires checking BASE and completing native-stack linking before verification. These two sequences disagree about when invalid topology must stop the iteration. Fix: Reorder the contract to implementer return, return validation, BASE check, native-stack discovery/linking, CI wait, and verifier dispatch; reference that canonical sequence from SKILL.md.
- **medium** `orchestrator.md`: The state guidance permits an implementer to move its story into 3_in-progress while working, then categorically says to move the file only after the implementer returns. The latter prohibition does not distinguish orchestrator routing from implementer-local progress tracking. Fix: Scope the post-return requirement to orchestrator outcome-routing moves and explicitly exempt optional implementer-local 3_in-progress moves on the story branch.
- **medium** `teams.md`: The exact phase-2 text instructs the implementer to wait on CI, while the fixed brief and orchestrator contract require implementers not to wait and assign CI waiting to the orchestrator. Fix: Replace the phase-2 CI-wait instruction with an immediate structured return after opening the pull request and completing permitted runtime cleanup; retain CI waiting in the orchestrator.
- **medium** `SKILL.md`: Core rules are repeatedly explained across the entry point, orchestrator contract, adapter notes, brief, and runners, producing approximately 14 duplicated concepts. Several contradictions arise where these repeated versions drift. Fix: Keep SKILL.md as an authorization boundary and concise workflow index, centralize orchestration in orchestrator.md and verification in verify.md, and replace repeated explanations elsewhere with links while retaining necessary dispatch-template directives.

## Summary

The skill covers its advertised workflow and provides concrete operational contracts, but conflicting authorization and lifecycle instructions undermine consistent execution. Its approximate weighted score is 0.95/2.00; resolve the five directive conflicts and consolidate repeated guidance before relying on unattended runs.
