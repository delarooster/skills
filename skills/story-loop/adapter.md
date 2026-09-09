# Adapter

Per-repo configuration at `tasks/story-loop.md`. Written by the loop on first run,
read on every run after. It never ships with the skill.

## Probe order

| Field | Probe | Default |
|---|---|---|
| Queue root | `stories/`, then `tasks/stories/`, then ask | none |
| Log path | beside the queue root | `tasks/loop-log.md` |
| Base branch | current upstream default, confirm once | none |
| Stack mode | `linear` unless declared | `linear` |
| Stack depth cap | soft, note-only when exceeded | `10` |
| Forge | forge CLI if a matching remote, else ask | `none` |
| Verifier | repo-declared reviewer agent, else none | `none` |
| Escalation threshold | only meaningful with a verifier | `8` |

Ask at most once per field, then write the answers and never ask again. A repo
with an adapter is configured; a repo without one configures itself on first use.

`forge: none` is a first-class mode, not a degradation to apologise for: the loop
chains branches and skips pull request creation entirely. `scripts/e2e-chain.sh`
runs in exactly this mode.

## Template

```markdown
# story-loop adapter

| Field | Value |
|---|---|
| Queue root | stories |
| Log path | tasks/loop-log.md |
| Base branch | develop |
| Stack mode | linear |
| Stack depth cap | 10 |
| Forge | gh |
| Verifier | pr-judge |
| Escalation threshold | 8 |
```

The threshold is the score at or above which the loop stops for a human instead of
remediating. It requires a verifier that returns an `ESCALATION` field; with
`Verifier: none` it is inert. Setting it to `0` escalates everything, which is the
old behaviour of stopping on any blocking finding. Setting it above `10` never
escalates, which is a choice worth making deliberately or not at all.

## Why not arguments

The loop is invoked by the host's repeat mechanism, which replays one fixed
prompt. Configuration passed as arguments would have to be retyped identically
every iteration, and would be lost on a cold start. It lives in a file for the
same reason the log does.
