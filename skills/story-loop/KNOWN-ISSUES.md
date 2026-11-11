# Known issues (2026-11-11)

Open review findings, not yet fixed. One line each; the location is where the fix lands.

- **DAG parent with two dependencies.** `parent` stacks on the last-landed dependency only, so the other dependency's branch is missing from the child's tree. `scripts/loop-state.sh:336`
- **Adapter first-run duplicate.** Until the tasks-only adapter pull request merges, a fresh checkout finds no adapter and probes and opens a second one. `SKILL.md:87`
- **Lane release after a crash.** A `held` line whose implementer crashed with `STACK: up` has no rule for tearing the runtime down or releasing the lane. `teams.md:13`, `teams.md:41`
- **Phase 1 versus the template wording.** The brief says to open the pull request, while the phase 1 text says not to; only the phase line resolves it. `implementer-brief.md:49`, `teams.md:59`
- **Re-verify after merging the base.** When an implementer merges its moved parent or the base into a verified branch, nothing requires a fresh verdict on the new head. `teams.md:15`, `verify.md:127`
- **Worktree removal on Codex and OpenCode.** The runners make the orchestrator remove worktrees, which is not in the permitted writes. `runner-codex.md:75`, `runner-opencode.md:41`
- **Unsatisfiable-dependency rows count toward the blocked stop.** Two `blocked :: dependency unsatisfiable` rows in a row stop the loop, although nothing was dispatched. `SKILL.md:149`, `orchestrator.md:130`
- **README omits anchor-selftest.** The public skills repo's README lists `selftest.sh` but not `anchor-selftest.sh`. `README.md:66` (public skills repo)
- **anchor-check's default root.** It defaults to `tasks/stories` while the adapter probes `stories/` first. `scripts/anchor-check.sh:16`, `adapter.md:12`
- **`Remediate should-fix: on` wording drift.** The `on` row says a leftover MERGE AFTER FIXES stops as `off` does, without the review-list exception stated just below it. `verify.md:79`
- **Teams stop list.** The loop-wide stops omit `judge unavailable` and operator sign-offs, which the main stop list has. `teams.md:19`, `SKILL.md:146`
- **Native stack conflicts still stop.** An unavailable extension or stacks API now skips linking, but an ambiguous parent pull request, a conflicting stack membership or a post-link verification mismatch still logs `blocked :: native stack`. `native-stacks.md:26`, `native-stacks.md:38`, `native-stacks.md:60`
- **Branch names lose `|`.** `append` maps `|` to `/` in every field, so a branch name containing `|` is logged under a different name than git's. `scripts/loop-state.sh:397`
- **First row for an id wins; no re-queue procedure.** `outcome` and dependency resolution read the first row for a story, so a story re-run after a block keeps its old outcome, and no step says how to re-queue one. `scripts/loop-state.sh:178`, `scripts/loop-state.sh:242`
- **The public command names files the skill no longer uses.** `commands/story-loop.md` still says the skill claims precedence over `INSTRUCTIONS.md` and `commands/git.md`. `commands/story-loop.md:9` (public skills repo)
