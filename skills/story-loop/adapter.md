# Adapter

Per-repo configuration at `tasks/story-loop.md`. Written on first run on a branch
and landed through a tasks-only pull request, never in the main checkout; read on
every run after. It never ships with the skill; the probe below fills it. This file is the field contract: the
agents, the templates and `loop-state.sh` all read these names.

## Fields

| Field | Probe | Default |
|---|---|---|
| Queue root | `stories/`, then `tasks/stories/`, then ask | none, required |
| Log path | beside the queue root | `tasks/loop-log.md` |
| Base branch | current upstream default, confirm once | none, required |
| Remote | the remote the base branch tracks | `origin` |
| Stack mode | `linear` unless declared | `linear` |
| Stack depth cap | integer, or `none` to never note | `10` |
| Forge | `gh` for a GitHub remote, `az` for an Azure DevOps remote, else ask | `none` |
| CI system | `.github/workflows/` is `github-actions`; `azure-pipelines.yml` or `.azure-pipelines/` is `azure-pipelines` | `none` |
| CI wait | minutes the orchestrator waits for checks to leave pending; implementers do not wait | `4` |
| Verifier | repo-declared reviewer agent, else none | `none` |
| Verdict dir | outside every checkout | `~/.local/state/pr-verdicts/<repo>` |
| Verdict archive | ask once; never inferred | `tasks/archive/reviews/` |
| Review rubric | a repo gates file for the verifier | `none` (the verifier's own gates) |
| Unverifiable gates | gates that can never be evidenced on a pull request here | `none` |
| Escalation threshold | only meaningful with a verifier | `8` |
| Merge policy | ask once; never inferred | `never` |
| Human-only categories | only meaningful with `clean-verdict` | `auth, payments, migrations` |
| Remediate should-fix | ask once; never inferred | `off` |
| Review list | never probed; declared by the operator | `none` |
| Native stacks | never probed | `auto` |
| Setup command | the task runner's install target | `none` |
| Build command | `AGENTS.md`, then the task runner, then CI | `none` |
| Test command | same; it provisions an isolated test database if tests need one | `none` |
| E2E command | same | `none` |
| E2E in PR CI | does per-change CI run the end-to-end suite | `no` |
| Narrowed e2e | a dispatchable e2e workflow or pipeline with a spec input, else ask | `none` |
| Stack policy | ask once | `ask` |
| Stack up command | the repo's local stack start target | `none` |
| Stack down command | the repo's non-destructive stop target | `none` |
| Test DB command | a target that starts a throwaway test database on its own port | `none` |
| Worktree env files | gitignored files a fresh worktree needs copied in | `none` |
| Scratch root | a directory outside the checkout | `${TMPDIR:-/tmp}/story-loop/<repo>` |
| Model tiers | | `implementer=standard verifier=standard filer=light` |
| Implementer agent | an agent definition the repo or host installs for stories | `story-implementer` |
| Closeout by | ask once; never inferred | `orchestrator` |
| Full runs at | `AGENTS.md`, then CI | `ci` |

Teams fields (`Lanes`, `Stack lock`, `Stack lock format`, `Phase-1 cap` and the
`Teams` table) are never probed; see [Teams and lanes](#teams-and-lanes).

Ask at most once per field, then write the answers and never ask again. Any field
may be omitted; the default applies. Earlier names still read, as aliases:
`Local stack policy` for Stack policy, `Local stack teardown` for Stack down
command, `Isolated test DB` for Test DB command, `Merge exclusions` for Human-only
categories. `"$LS" adapter-check tasks/story-loop.md`
validates the file and prints every field with its effective value; run it after
writing and at the start of each iteration. `"$LS" adapter <file> <field>` reads
one value, default applied.

`forge: none` is a first-class mode, not a degradation to apologise for: the loop
chains branches and skips pull request creation entirely. `scripts/e2e-chain.sh`
runs in exactly this mode. With no forge there is nothing to merge through, so
`adapter-check` rejects `Merge policy: clean-verdict` alongside `Forge: none` or
`Verifier: none`.

## Template

```markdown
# story-loop adapter

| Field | Value |
|---|---|
| Queue root | tasks/stories |
| Base branch | main |
| Forge | gh |
| CI system | github-actions |
| Verifier | pr-judge |
| Merge policy | never |
| Build command | make build |
| Test command | make test |
| Stack policy | ask |
| Stack down command | make stack-down |
```

## Monorepo: commands by path

One adapter. The `* command` fields are repo-wide defaults. A repo whose packages
build differently adds an optional section; a row overrides only the cells it
fills, and a path of `.` is the root:

```markdown
## Commands

| Path | Setup | Build | Test | E2E |
|---|---|---|---|---|
| services/api | make -C services/api deps | make -C services/api build | make -C services/api test | |
| web | npm --prefix web ci | npm --prefix web run build | npm --prefix web test | npm --prefix web run e2e |
```

`"$LS" command <adapter> <column> <path>` returns the longest matching row's cell,
else the `<column> command` field. A story may list the paths it touches in a
`**Paths:**` header (`"$LS" paths <story>`); the implementer runs the commands for
each. Columns are free-form, so `Lint` or `Typecheck` need no schema change.
Nothing requires the section.

## Polyrepo: one adapter per repo, one optional workspace queue

Each repo keeps its own `tasks/story-loop.md`. Stories that span repos may live in
one workspace queue, whose adapter adds a repo map:

```markdown
## Repos

| Repo | Checkout | Adapter |
|---|---|---|
| api | ../api | ../api/tasks/story-loop.md |
| web | ../web | ../web/tasks/story-loop.md |
```

A workspace story names its target with a `**Repo:** <name>` header, read with
`"$LS" repo <story>`; `"$LS" repo-path <adapter> <name>` prints the checkout. The
iteration then uses **that repo's** adapter for base, forge, commands and merge
policy, and the workspace adapter only for queue root and log. The workspace log
records the branch as `<repo>:<branch>`; pass the repo as the last argument to
`head`, `depth` and `parent` so a chain only ever stacks inside one repo. A
dependency in another repo gates eligibility but never becomes a git parent; within
its own repo such a story is placed as if it declared `None`.

A member repo's adapter may point `Queue root` and `Log path` at the workspace,
e.g. `../workspace/tasks/stories`. Relative path fields resolve against the root of
the repo holding the adapter, never the caller's cwd: read them with
`"$LS" adapter-path <file> <field>`, which prints an absolute path.

## Field notes

**Escalation threshold.** The score at or above which the loop stops for a human
instead of remediating. It requires a verifier that satisfies the return
contract in [verify.md](verify.md); with `Verifier: none` it is
inert. `0` or `1` escalates every BLOCKING hold; above `10` never escalates one,
which is a choice worth making deliberately or not at all.

**Merge policy.** A per-repo decision: teams differ in how comfortable they are
with agentic merges, so the safe default holds. `never` leaves every pull request
for a human. `clean-verdict`, opt-in and set explicitly,
lets the loop merge a story's pull request through the forge's merge verb
([chain.md](chain.md)), merge commit only, when `"$LS" merge-gate` passes: verdict
`MERGE`, BLOCKING 0, ESCALATION 0, CI green on the closeout head, every unmet
acceptance criterion filed forward as its own story, and no category of the story
in `Human-only categories`. The escalation threshold still routes first. A human
sets this field and records why in the repo's decision log; the loop never
proposes changing it.

**Remediate should-fix.** `off` (default): a MERGE AFTER FIXES verdict stops
the loop for a human. `on`: the loop remediates the SHOULD FIX findings for at
most 2 rounds, a fresh verifier each round, then applies the merge policy.
BLOCKING remediation below the escalation threshold is unaffected by this field.

**Human-only categories.** Comma list matched against the story's optional
`**Categories:**` header. A story in any of them never merges unattended: its pull
request waits for the full suite and a person. Deleting the defaults is a decision,
not a cleanup.

**Verdict dir.** Applies only to a verifier that takes an output directory: it
writes `pr-<N>.md` there, outside every checkout, so a verdict never rides a story
branch by accident and never dirties the main checkout. A verifier that writes into
the checkout instead ([verify.md](verify.md#verifier-subagent)) ignores it. Either
way the loop uses the `PATH` the verifier returns, never a path built from this field.

**Verdict archive.** Where the closeout commit copies a clean verdict, default
`tasks/archive/reviews/`, copied from the `PATH` the verifier returned. `none`:
nothing is copied and the closeout deletes the file at that `PATH` instead, for repos whose rules keep verdicts out of
the tree entirely. A relative path resolves against the story's worktree, where the
closeout commit is made.

**Native stacks.** `auto` (default): link sequential linear pull requests into a
GitHub native stack when the `gh stack` extension and the stacks API are available,
and skip with a log note when they are not. `off`: never link; git branches carry
the chain alone ([native-stacks.md](native-stacks.md)).

**Review list.** A file path outside every checkout. `none` (default): a MERGE AFTER
FIXES that remediation did not clear, and any operator sign-off a story asks for,
stop the loop. With a path, both go on the list and the loop continues
([verify.md](verify.md#review-list)).

**CI.** Heavy jobs (image builds, the end-to-end suite, deploys) belong off the
per-change path: nightly plus manual dispatch, and deploys on dispatch alone. Draft
status then changes nothing CI runs, so open pull requests as drafts only when they
are drafts.
A story's scoped checks run where the implementer works; its full proof goes to
`Full runs at`. When a stack proof is needed and per-change CI skips it, dispatch
**one** narrowed run. One full run per check, then narrowed runs only, one at a
time. Examples, not defaults:

| CI system | Narrowed e2e example |
|---|---|
| `github-actions` | `gh workflow run e2e.yml --ref <branch> -f spec='<specs>'` |
| `azure-pipelines` | `az pipelines run --name e2e --branch <branch> --parameters spec=<specs>` |

The verifier costs no CI minutes; dispatch it on every pull request.

**Stack policy.** `ask`: no agent starts the app, its database or its containers
without the operator's go-ahead, because an operator's own build may hold the same
ports and volumes; an implementer uses a stack already up, or stops where only the
stack proof remains and says so in `DEVIATIONS`. `own`: agents may start and stop
it. `none`: no local stack; the proof goes to the narrowed CI run.
`Stack down command` is the only stop agents use and must keep shared volumes; CI
recipes tear down a throwaway runner and must not be copied to a workstation.
`adapter-check` rejects a volume-deleting value such as `docker compose down -v`.
`Test DB command` points tests at a throwaway container, never a shared developer
database; skipped database tests are a defect to report, not an outcome. Shared
environments are seeded add-only.

**Implementer agent.** The agent type the runner spawns for each story. A repo
whose implementer rules live in its own agent definition names it here, so those
rules reach every dispatch rather than depending on which agent the orchestrator
picks. If the named agent is not installed, the runner falls back to
`general-purpose` with the whole brief template.

**Closeout by.** Who makes the closeout commit on a clean verdict
([orchestrator.md](orchestrator.md#closeout)). `orchestrator`: the orchestrator
commits `tasks/` only on the story branch. `implementer`: the orchestrator sends the
closeout to the warm implementer, which commits and pushes it; use this where the
repo's git rules let only implementers commit. Either way it is the last commit on
the branch, and nothing is written in the main checkout.

**Full runs at.** Where full test suites, full builds and end-to-end runs happen.
`ci` (default): the implementer runs only scoped checks for what it changed and
leaves the rest to CI, dispatching `Narrowed e2e` when per-change CI skips it. Any
other value names the place the repo provides (a lane, a runner, a remote host) in
one line the implementer can act on. The machine the agent was spawned on is never
the default.

**Scratch root.** Every agent writes temp files under `<Scratch root>/<story id>/`.
Parallel implementers inherit one session scratchpad, so a fixed filename like
`body.md` leaks one pull request's text into another.

**Model tiers.** `implementer`, `verifier` and `filer`, each `heavy`, `standard` or
`light`. The rendered agent definitions map tiers to models per harness. Filing is
bookkeeping from a clear brief: give it the cheapest tier that follows the rules,
and never a fork of the orchestrator's context.

## Repo notes

Rules that are the repo's own go in prose below the table. Two apply everywhere:

- **Depth is measured even when uncapped.** `Stack depth cap: none` stops the
  note, not the count. The risk at depth is two stories editing one file with
  nothing merging to resolve them; the implementer names any such overlap in the
  pull request body, and the orchestrator in the log row.
- **The implementer reads this file but not its prose.** A rule an implementer
  must follow belongs in a field, in its agent definition, or in a brief slot.

## Teams and lanes

Optional. With no `Teams` table the loop runs exactly as described everywhere
else: one implicit team, one story in flight. Behaviour: [teams.md](teams.md).

```markdown
| Lanes | 1 |
| Stack lock | <path outside the repo, untracked like the log> |
| Phase-1 cap | 3 |

## Teams

| Team | Surface | Stories |
|---|---|---|
| api | server code | SS.03, SS.01, SS.04 |
| web | client code | TT.02, TT.05 |
```

| Field | Meaning |
|---|---|
| `Team` | Name used in `"$LS" eligible ... --team <name> <adapter>` and the brief's `TEAM:` slot |
| `Surface` | The paths or area the team owns. Teams with overlapping surfaces conflict, so do not declare them |
| `Stories` | Ordered ids, comma or space separated. Table order replaces queue order for that team. An id in no team is never dispatched while the table exists |
| `Lanes` | How many shared runtimes (stack, database, end-to-end environment) can run at once. Default `1` |
| `Stack lock` | File the orchestrator writes to grant a lane; required only when lanes < teams. Untracked, for the same reason the log is |
| `Stack lock format` | `loop` (default; the line format in [teams.md](teams.md)) or the repo's own line format, when its checklists already read the lock |
| `Phase-1 cap` | Most implementers working without a lane at once; default the team count. Caps cost, not correctness |

`"$LS" teams <adapter>` prints `team<TAB>id,id,...` per team; empty means one
implicit team.

## Why not arguments

The loop is invoked by the host's repeat mechanism, which replays one fixed
prompt. Configuration passed as arguments would have to be retyped identically
every iteration, and would be lost on a cold start. It lives in a file for the
same reason the log does.
