#!/usr/bin/env bash
# selftest.sh -- exercise loop-state.sh against a throwaway story queue.
#
# Builds a scratch queue in a temp dir, then asserts every deterministic decision
# the orchestrator is allowed to make. Touches nothing outside its own temp dir
# and runs no git commands. Safe to run anywhere, any time.
#
#   skills/story-loop/scripts/selftest.sh

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
LS="$HERE/loop-state.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/story-loop-selftest.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }
exits(){ # exits <label> <expected-code> <cmd...>
  local label="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then ok "$label"; else bad "$label" "exit $want" "exit $got"; fi
}

Q="$WORK/stories"; LOG="$WORK/loop-log.md"; BASE="develop"
mkdir -p "$Q/1_backlog" "$Q/2_ready" "$Q/3_in-progress" "$Q/6_completed"

story() { # story <folder> <file> <id> <deps> <effort>
  cat > "$Q/$1/$2" <<EOF
# $3: Scratch story $3

**Epic:** Z
**Effort:** $5
**Dependencies:** $4
**Skillsets:** none

---

## Description

SENTINEL_BODY_TEXT that the orchestrator must never read.

## Acceptance Criteria

- [ ] does the thing
EOF
}

story 2_ready   Z-01-first.md  ZZ.01 None  1
story 1_backlog Z-02-second.md ZZ.02 None  2
story 1_backlog Z-03-third.md  ZZ.03 ZZ.02  3
story 1_backlog Z-04-dependent-on-blocked.md ZZ.04 ZZ.09 1
# a story parked in a non-queue folder must not be picked up
story 3_in-progress Z-99-inflight.md ZZ.99 None 1

echo "== index and read-nothing discipline =="
"$LS" init-log "$LOG"
eq "log header written" "| Story | Outcome | PR | Branch | Base | AC | CI | Verdict | Notes |" \
   "$(sed -n '3p' "$LOG")"
IDX=$("$LS" index "$Q")
eq "index finds 4 queue stories" "4" "$(printf '%s\n' "$IDX" | grep -c .)"
eq "2_ready sorts before 1_backlog" "ZZ.01" "$(printf '%s\n' "$IDX" | head -1 | cut -f1)"
eq "parses declared dependency" "ZZ.02" "$(printf '%s\n' "$IDX" | awk -F'\t' '$1=="ZZ.03"{print $2}')"
eq "parses effort" "2" "$(printf '%s\n' "$IDX" | awk -F'\t' '$1=="ZZ.02"{print $3}')"
eq "in-progress story is not a queue member" "" \
   "$(printf '%s\n' "$IDX" | awk -F'\t' '$1=="ZZ.99"{print $1}')"
if printf '%s\n' "$IDX" | grep -q SENTINEL_BODY_TEXT; then
  bad "index never emits story body" "no body text" "body text leaked"
else
  ok "index never emits story body"
fi

echo "== chain head on a cold start =="
eq "empty log: head is the base" "$BASE" "$("$LS" head "$LOG" "$BASE")"
eq "empty log: depth 0" "0" "$("$LS" depth "$LOG" "$BASE")"
eq "first eligible is ZZ.01" "ZZ.01" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "ZZ.01 parent is the base" "$BASE" "$("$LS" parent "$LOG" "$BASE" linear None)"

echo "== pending dependencies are not stalled dependencies =="
# ZZ.03 depends on ZZ.02, which is still queued. That is a wait, not a block.
eq "a dependency still in the queue is pending, not stalled" "" \
   "$("$LS" stalled "$Q" "$LOG" | awk -F'\t' '$1=="ZZ.03"{print $1}')"

echo "== stacking: the bug this exists to prevent =="
"$LS" append "$LOG" ZZ.01 landed 101 feat/z-01 "$BASE" 1/1 green PASS -
eq "head advances to the landed branch" "feat/z-01" "$("$LS" head "$LOG" "$BASE")"
eq "next story is ZZ.02" "ZZ.02" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "linear: independent story stacks on head" "feat/z-01" \
   "$("$LS" parent "$LOG" "$BASE" linear None)"
eq "dag: independent story roots at base" "$BASE" \
   "$("$LS" parent "$LOG" "$BASE" dag None)"

"$LS" append "$LOG" ZZ.02 landed 102 feat/z-02 feat/z-01 2/2 green PASS -
eq "declared dependency picks its branch, not the head" "feat/z-02" \
   "$("$LS" parent "$LOG" "$BASE" linear ZZ.02)"
eq "depth counts the chain" "2" "$("$LS" depth "$LOG" "$BASE")"

echo "== blocked rows must not corrupt the chain =="
"$LS" append "$LOG" ZZ.03 blocked - - - 0/3 absent HOLD "underspecified"
eq "blocked row does not advance the head" "feat/z-02" "$("$LS" head "$LOG" "$BASE")"
eq "blocked row does not count toward depth" "2" "$("$LS" depth "$LOG" "$BASE")"
eq "outcome reads back" "blocked" "$("$LS" outcome "$LOG" ZZ.03)"

echo "== a story must never be silently skipped =="
# ZZ.04 depends on ZZ.09, which is in neither the queue nor the log. It can never
# become eligible. If the loop only asked "what is eligible?" the queue would
# look drained while ZZ.04 vanished unlogged.
eq "unsatisfiable story is not eligible" "" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "but it IS reported as stalled" "ZZ.04" "$("$LS" stalled "$Q" "$LOG" | cut -f1)"
eq "with the dependency that can never be met" "ZZ.09" "$("$LS" stalled "$Q" "$LOG" | cut -f2)"
"$LS" append "$LOG" ZZ.04 blocked - - - 0/1 absent HOLD "dep ZZ.09 unsatisfiable"
eq "once logged, it stops being reported" "" "$("$LS" stalled "$Q" "$LOG")"
eq "queue is genuinely drained" "" "$("$LS" eligible "$Q" "$LOG")"

echo "== a dependency completed outside the log still counts =="
# The log is untracked and starts empty on a fresh checkout, so work finished by
# an earlier run -- or by hand -- exists only as a file in 6_completed. Read the
# log alone and every dependent of that work is unsatisfiable forever.
# Three of them, deliberately. With a single completed story the match always
# lands on the last line, which is exactly the case where a `producer | grep -q`
# membership test does NOT die on SIGPIPE. A one-item fixture reports PASS on a
# lookup that is broken for every real queue.
story 6_completed z-20.md ZZ.20 None 1
story 6_completed z-22.md ZZ.22 None 1
story 6_completed z-23.md ZZ.23 None 1
story 1_backlog   z-21.md ZZ.21 ZZ.20 2
eq "6_completed is still not a queue member" "" \
   "$("$LS" index "$Q" | awk -F'\t' '$1=="ZZ.20"{print $1}')"
eq "the completed ledger sees all three" "ZZ.20 ZZ.22 ZZ.23" \
   "$("$LS" completed "$Q" | tr '\n' ' ' | sed 's/ $//')"
eq "a match on the FIRST line is found, not lost to SIGPIPE" "ZZ.21" \
   "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "its dependent becomes eligible" "ZZ.21" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "and is never reported stalled" "" \
   "$("$LS" stalled "$Q" "$LOG" | awk -F'\t' '$1=="ZZ.21"{print $1}')"
eq "a merged dependency roots at the base, not a stale branch" "$BASE" \
   "$("$LS" parent "$LOG" "$BASE" linear ZZ.20)"

echo "== the log is trimmed to its newest rows =="
RLOG="$WORK/trim-log.md"
for i in $(seq 1 60); do "$LS" append "$RLOG" - stop - - - - - - "stop-$i"; done
eq "append trims stop rows to the header plus the last 50" "54" "$(wc -l < "$RLOG" | tr -d ' ')"
eq "trim keeps the header" "# story-loop log" "$(head -n 1 "$RLOG")"
eq "trim drops the oldest stop rows" "stop-11" "$(sed -n 5p "$RLOG" | awk -F'|' '{gsub(/ /,"",$10); print $10}')"
eq "trim keeps the newest row" "stop-60" "$(tail -n 1 "$RLOG" | awk -F'|' '{gsub(/ /,"",$10); print $10}')"
MLOG="$WORK/trim-merged.md"
for i in $(seq 1 60); do "$LS" append "$MLOG" "row-$i" landed "$i" "feat/row-$i" main 1/1 green PASS merged; done
eq "story rows are never trimmed, merged ones included" "60" "$(grep -c '| landed |' "$MLOG")"
eq "merged rows leave the depth count" "0" "$("$LS" depth "$MLOG" main)"
HLOG="$WORK/trim-head.md"
"$LS" append "$HLOG" HH.01 landed 1 feat/hh-01 main 1/1 green PASS -
for i in $(seq 1 50); do "$LS" append "$HLOG" - stop - - - - - - "stop $i"; done
eq "trim keeps the newest chained row, so the head survives" "feat/hh-01" "$("$LS" head "$HLOG" main)"
eq "and the chain depth stays above zero" "1" "$("$LS" depth "$HLOG" main)"
eq "the trimmed log still holds 50 stop rows" "50" "$(grep -c '| stop |' "$HLOG")"
Q0="$Q"; Q="$WORK/trimq"; mkdir -p "$Q/1_backlog" "$Q/2_ready" "$Q/6_completed"
story 2_ready aa-01.md AA.01 None 1
story 2_ready aa-02.md AA.02 None 1
story 2_ready aa-03.md AA.03 AA.02 1
BLOG="$WORK/trim-blocked.md"
"$LS" append "$BLOG" AA.01 blocked - - - 0/1 absent HOLD "underspecified"
"$LS" append "$BLOG" AA.02 landed 2 feat/aa-02 main 1/1 green PASS -
"$LS" append "$BLOG" BB.01 landed 3 feat/bb-01 main 1/1 green PASS -
for i in $(seq 1 60); do "$LS" append "$BLOG" - stop - - - - - - "stop $i"; done
eq "a blocked row survives the trim" "blocked" "$("$LS" outcome "$BLOG" AA.01)"
eq "so a blocked story is not eligible again; an unmerged dependency still counts" "AA.03" \
   "$("$LS" eligible "$Q" "$BLOG" | cut -f1)"
eq "unmerged landed rows keep the depth" "2" "$("$LS" depth "$BLOG" main)"
eq "only stop rows were trimmed" "50" "$(grep -c '| stop |' "$BLOG")"
eq "every story row was kept" "3" "$(grep -c '^| [A-Z][A-Z]\.' "$BLOG")"
Q="$WORK/trimq2"; mkdir -p "$Q/1_backlog" "$Q/2_ready" "$Q/6_completed"
story 2_ready bb-01.md BB.01 None 1
GLOG="$WORK/trim-merged-queue.md"
"$LS" append "$GLOG" BB.01 landed 7 feat/bb-01 main 1/1 green 'MERGE(0)' merged
"$LS" append "$GLOG" CC.01 landed 8 feat/cc-01 main 1/1 green 'MERGE(0)' -
for i in $(seq 1 55); do "$LS" append "$GLOG" - stop - - - - - - "stop $i"; done
eq "a merged row survives 55 stop rows" "landed" "$("$LS" outcome "$GLOG" BB.01)"
eq "so a merged story still filed in 2_ready is not offered again" "" "$("$LS" eligible "$Q" "$GLOG" | cut -f1)"
Q="$Q0"

echo "== append keeps one row per call =="
PLOG="$WORK/pipe-log.md"
"$LS" append "$PLOG" PP.01 blocked - - - 0/1 absent HOLD "a|b
c"
eq "a pipe in a field does not add a column" "11" "$(tail -n 1 "$PLOG" | awk -F'|' '{print NF}')"
eq "a newline in a field does not add a row" "5" "$(wc -l < "$PLOG" | tr -d ' ')"
eq "the note reads back flattened" "a/b c" "$(tail -n 1 "$PLOG" | awk -F'|' '{gsub(/^ +| +$/,"",$10); print $10}')"

echo "== unstacked detection =="
exits "matching base passes" 0 "$LS" check-base feat/z-02 feat/z-02
exits "mismatched base fails"  1 "$LS" check-base feat/z-02 "$BASE"

echo "== cold start from the log alone =="
# Same assertions, fresh process, no memory of the run above.
eq "head survives a restart" "feat/z-02" "$("$LS" head "$LOG" "$BASE")"
eq "a resumed story stacks on the chain, not the base" "feat/z-02" \
   "$("$LS" parent "$LOG" "$BASE" linear None)"

echo "== adapter fields =="
AD="$WORK/story-loop.md"
cat > "$AD" <<'EOF'
# story-loop adapter

| Field | Value |
|---|---|
| Queue root | tasks/stories |
| Base branch | main |
| Stack depth cap | none |
| Forge | az |
| CI system | azure-pipelines |
| Verifier | pr-judge |
| Merge policy | clean-verdict |
| Test command | `make test` |
| Stack down command | make stack-down |

## Commands

| Path | Build | Test |
|---|---|---|
| . | make build | |
| services/api | make -C services/api build | make -C services/api test |
| services/api/worker | | make -C services/api/worker test |

## Repos

| Repo | Checkout | Adapter |
|---|---|---|
| web | ../web | ../web/tasks/story-loop.md |
EOF
eq "declared field reads back" "az" "$("$LS" adapter "$AD" Forge)"
eq "field names match case-insensitively" "azure-pipelines" "$("$LS" adapter "$AD" 'ci system')"
eq "backticks around a command are stripped" "make test" "$("$LS" adapter "$AD" 'Test command')"
eq "missing field takes its default" "ask" "$("$LS" adapter "$AD" 'Stack policy')"
eq "human-only categories default" "auth, payments, migrations" \
   "$("$LS" adapter "$AD" 'Human-only categories')"
eq "verdict dir defaults outside the checkout" '~/.local/state/pr-verdicts/<repo>' \
   "$("$LS" adapter "$AD" 'Verdict dir')"
eq "CI wait defaults to four minutes" "4" "$("$LS" adapter "$AD" 'CI wait')"
eq "model tiers default names all three roles" "implementer=standard verifier=standard filer=light" \
   "$("$LS" adapter "$AD" 'Model tiers')"
printf '| Local stack policy | own |\n' >> "$WORK/alias.md"
eq "an earlier field name reads as its alias" "own" "$("$LS" adapter "$WORK/alias.md" 'Stack policy')"
exits "a valid adapter passes" 0 "$LS" adapter-check "$AD"
eq "adapter-raw is empty for an unset field" "" "$("$LS" adapter-raw "$AD" 'Closeout by')"
printf '| merge exclusions | auth |\n|  Closeout by  |   |\n' > "$WORK/raw.md"
eq "adapter-raw reads an alias, any case" "auth" "$("$LS" adapter-raw "$WORK/raw.md" 'Human-only categories')"
eq "adapter-raw treats a blank value as unset" "" "$("$LS" adapter-raw "$WORK/raw.md" 'Closeout by')"
eq "should-fix remediation is off by default" "off" "$("$LS" adapter "$AD" 'Remediate should-fix')"
eq "native stacks are auto by default" "auto" "$("$LS" adapter "$AD" 'Native stacks')"
eq "no review list by default" "none" "$("$LS" adapter "$AD" 'Review list')"
eq "verdicts archive in the tree by default" "tasks/archive/reviews/" "$("$LS" adapter "$AD" 'Verdict archive')"
eq "implementer agent defaults to story-implementer" "story-implementer" "$("$LS" adapter "$AD" 'Implementer agent')"
eq "closeout defaults to the orchestrator" "orchestrator" "$("$LS" adapter "$AD" 'Closeout by')"
eq "stack lock format defaults to the loop's own" "loop" "$("$LS" adapter "$AD" 'Stack lock format')"
eq "full runs default to CI" "ci" "$("$LS" adapter "$AD" 'Full runs at')"
eq "merge policy is never by default" "never" "$("$LS" adapter "$WORK/alias.md" 'Merge policy')"
eq "adapter-check lists every field" "36" "$("$LS" adapter-check "$AD" | grep -c .)"

bad_adapter() { # bad_adapter <label> <field> <value>
  sed "/^| $2 |/d" "$AD" > "$WORK/bad.md"
  printf '| %s | %s |\n' "$2" "$3" >> "$WORK/bad.md"
  exits "$1" 1 "$LS" adapter-check "$WORK/bad.md"
}
bad_adapter "unknown forge rejected"          Forge github
bad_adapter "unknown CI system rejected"      'CI system' jenkins
bad_adapter "unknown merge policy rejected"   'Merge policy' always
bad_adapter "unknown should-fix value rejected" 'Remediate should-fix' yes
bad_adapter "unknown closeout owner rejected"  'Closeout by' verifier
bad_adapter "unknown stack policy rejected"   'Stack policy' sometimes
bad_adapter "clean-verdict without a forge rejected"    Forge none
bad_adapter "clean-verdict without a verifier rejected" Verifier none
bad_adapter "volume-deleting compose down rejected" 'Stack down command' 'docker compose down -v'
bad_adapter "long-form volume flag rejected" 'Stack down command' 'docker compose down --volumes'
bad_adapter "model tiers missing a role rejected" 'Model tiers' 'implementer=heavy verifier=heavy'
bad_adapter "non-numeric threshold rejected"  'Escalation threshold' high
bad_adapter "missing queue root rejected"     'Queue root' ''

echo "== monorepo commands by path =="
eq "a path row overrides the field" "make -C services/api test" \
   "$("$LS" command "$AD" Test services/api/src/app.ts)"
eq "the longest matching path wins" "make -C services/api/worker test" \
   "$("$LS" command "$AD" Test services/api/worker/job.ts)"
eq "a blank cell falls to a shorter row" "make -C services/api build" \
   "$("$LS" command "$AD" Build services/api/worker/job.ts)"
eq "the root row covers unmatched paths" "make build" "$("$LS" command "$AD" Build docs/x.md)"
eq "no row and no column falls to the field" "make test" "$("$LS" command "$AD" Test docs/x.md)"
eq "a prefix is not a path match" "make build" "$("$LS" command "$AD" Build services/apiary/x)"
eq "no section at all falls to the field" "none" "$("$LS" command "$WORK/alias.md" Test web)"

echo "== polyrepo workspace queue =="
eq "repo-path resolves a workspace repo" "../web" "$("$LS" repo-path "$AD" web)"
exits "an unknown repo fails" 1 "$LS" repo-path "$AD" nope
WL="$WORK/ws-log.md"
"$LS" init-log "$WL"
"$LS" append "$WL" WW.01 landed 1 api:feat/w-01 main 1/1 green 'MERGE(0)' -
"$LS" append "$WL" WW.02 landed 2 web:feat/w-02 main 1/1 green 'MERGE(0)' -
"$LS" append "$WL" WW.03 landed 3 api:feat/w-03 feat/w-01 1/1 green 'MERGE(0)' -
eq "a repo's chain head ignores other repos" "feat/w-02" "$("$LS" head "$WL" main web)"
eq "and strips the repo prefix" "feat/w-03" "$("$LS" head "$WL" main api)"
eq "depth counts one repo" "2" "$("$LS" depth "$WL" main api)"
eq "a repo with no rows roots at its base" "main" "$("$LS" head "$WL" main docs)"
eq "a cross-repo dependency is never a git parent: linear stacks on the repo head" "feat/w-03" \
   "$("$LS" parent "$WL" main linear WW.02 api)"
eq "and dag roots it at the base" "main" "$("$LS" parent "$WL" main dag WW.02 api)"
eq "linear stacks a same-repo dependency on the repo head" "feat/w-03" "$("$LS" parent "$WL" main linear WW.01 api)"
eq "dag stacks it on the dependency" "feat/w-01" "$("$LS" parent "$WL" main dag WW.01 api)"

echo "== native stack gate =="
eq "a root needs no parent PR or stack" "skip :: root" "$("$LS" native-stack gh linear no main main)"
eq "a DAG sibling keeps its computed base" "skip :: dag" "$("$LS" native-stack gh dag no feat/parent main)"
eq "teams never append into a shared native chain" "skip :: teams" "$("$LS" native-stack gh linear yes feat/parent main)"
eq "ADO uses branch stacking only" "skip :: forge" "$("$LS" native-stack az linear no feat/parent main)"
eq "forge none uses branch stacking only" "skip :: forge" "$("$LS" native-stack none linear no feat/parent main)"
mkdir -p "$WORK/gh-ok" "$WORK/gh-none"
printf '#!/bin/sh\nexit 0\n' > "$WORK/gh-ok/gh"
printf '#!/bin/sh\n[ "$1" = stack ] && exit 1\nexit 0\n' > "$WORK/gh-none/gh"
chmod +x "$WORK/gh-ok/gh" "$WORK/gh-none/gh"
eq "a sequential linear child needs native linking" "link" \
   "$(PATH="$WORK/gh-ok:$PATH" "$LS" native-stack gh linear no feat/parent main)"
eq "no gh stack extension skips, never blocks" "skip :: no gh stack" \
   "$(PATH="$WORK/gh-none:$PATH" "$LS" native-stack gh linear no feat/parent main auto)"
eq "native stacks off never links" "skip :: off" \
   "$(PATH="$WORK/gh-ok:$PATH" "$LS" native-stack gh linear no feat/parent main off)"
exits "an unknown native setting cannot enable linking" 2 "$LS" native-stack gh linear no feat/parent main maybe
exits "an unknown mode cannot enable linking" 2 "$LS" native-stack gh unknown no feat/parent main
exits "an unknown team flag cannot enable linking" 2 "$LS" native-stack gh linear maybe feat/parent main
exits "a missing parent cannot enable linking" 2 "$LS" native-stack gh linear no '' main
exits "native stack gate requires all arguments" 2 "$LS" native-stack gh linear no

echo "== merge gate =="
HO="auth, payments, migrations"
eq "clean verdict merges" "merge" \
   "$("$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no ui "$HO")"
exits "policy never holds" 1 "$LS" merge-gate never MERGE 0 0 green 3/3 no ui "$HO"
exits "MERGE AFTER FIXES holds" 1 "$LS" merge-gate clean-verdict 'MERGE AFTER FIXES' 0 0 green 3/3 no ui "$HO"
exits "a blocking finding holds" 1 "$LS" merge-gate clean-verdict MERGE 1 3 green 3/3 no ui "$HO"
exits "a nonzero escalation holds" 1 "$LS" merge-gate clean-verdict MERGE 0 2 green 3/3 no ui "$HO"
exits "red CI holds" 1 "$LS" merge-gate clean-verdict MERGE 0 0 red 3/3 no ui "$HO"
eq "spaces in the criteria count are accepted" "merge" \
   "$("$LS" merge-gate clean-verdict MERGE 0 0 green '3 / 3' no ui "$HO")"
exits "spaced unmet criteria still hold" 1 "$LS" merge-gate clean-verdict MERGE 0 0 green '2 / 3' no ui "$HO"
for bad in 'a/b' '3/0' '0/0' '4/3' '3' '3/3/3' '/3'; do
  exits "malformed criteria count '$bad' holds" 1 "$LS" merge-gate clean-verdict MERGE 0 0 green "$bad" yes ui "$HO"
done
exits "a singular category matches a plural default" 1 "$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no migration "$HO"
exits "a slash-joined category matches" 1 "$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no 'auth/payments' "$HO"
exits "case, semicolons and spaces still match" 1 "$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no 'UI; Payment' "$HO"
eq "an unrelated category still merges" "merge" \
   "$("$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no 'ui copy' "$HO")"
eq "a story with no categories never matches human-only none" "merge" \
   "$("$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no none none)"
eq "human-only none still holds nothing for a real category" "merge" \
   "$("$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no auth none)"
exits "unmet criteria not filed forward hold" 1 "$LS" merge-gate clean-verdict MERGE 0 0 green 2/3 no ui "$HO"
eq "unmet criteria filed forward merge" "merge" \
   "$("$LS" merge-gate clean-verdict MERGE 0 0 green 2/3 yes ui "$HO")"
eq "a human-only category holds and says which" "hold :: human-only category payment" \
   "$("$LS" merge-gate clean-verdict MERGE 0 0 green 3/3 no 'UI, Payments' "$HO")"
exits "wrong argument count refuses" 2 "$LS" merge-gate clean-verdict MERGE 0 0 green
printf '**Categories:** auth, ui\n**Paths:** services/api, web\n**Repo:** api\n' > "$WORK/hdr.md"
eq "categories header reads back" "auth, ui" "$("$LS" categories "$WORK/hdr.md")"
eq "paths header reads back" "services/api, web" "$("$LS" paths "$WORK/hdr.md")"
eq "repo header reads back" "api" "$("$LS" repo "$WORK/hdr.md")"
eq "no categories header reads as none" "none" "$("$LS" categories "$Q/2_ready/Z-01-first.md")"

echo "== teams: per-team heads from the adapter's Teams table =="
Q="$WORK/teams"; TLOG="$WORK/teams-log.md"; TAD="$WORK/teams-adapter.md"
mkdir -p "$Q/1_backlog" "$Q/2_ready" "$Q/6_completed"
story 2_ready     t-01.md TT.01 None 1
story 2_ready     t-02.md TT.02 None 1
story 1_backlog   t-03.md TT.03 None 1
story 1_backlog   t-04.md TT.04 TT.01 1
story 1_backlog   t-05.md TT.05 TT.04 1
story 6_completed t-00.md TT.00 None 1
cat > "$TAD" <<'EOF'
# story-loop adapter

| Field | Value |
|---|---|
| Base branch | develop |
| Lanes | 1 |

## Teams

| Team | Surface | Stories |
|---|---|---|
| api | server | TT.03, TT.01, TT.04 |
| web | client | TT.00 TT.02,TT.05 |

| Other | Table |
|---|---|
| zz | TT.99 |
EOF
"$LS" init-log "$TLOG"
eq "teams lists both teams and stops at the table end" "2" "$("$LS" teams "$TAD" | grep -c .)"
eq "teams joins ids in table order" "$(printf 'api\tTT.03,TT.01,TT.04')" \
   "$("$LS" teams "$TAD" | head -1)"
eq "teams accepts spaces and commas as separators" "$(printf 'web\tTT.00,TT.02,TT.05')" \
   "$("$LS" teams "$TAD" | sed -n 2p)"
eq "an adapter without Teams lists none" "" "$("$LS" teams "$WORK/loop-log.md")"
exits "teams without an adapter fails" 2 "$LS" teams "$WORK/missing.md"
eq "unfiltered eligible keeps queue order" "TT.01" "$("$LS" eligible "$Q" "$TLOG" | cut -f1)"
eq "team order beats queue order" "TT.03" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$TAD" | cut -f1)"
eq "team output keeps the index shape" "4" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$TAD" | awk -F'\t' '{print NF}')"
eq "a listed story outside the queue is skipped" "TT.02" \
   "$("$LS" eligible "$Q" "$TLOG" --team web "$TAD" | cut -f1)"
exits "unknown team fails" 2 "$LS" eligible "$Q" "$TLOG" --team ops "$TAD"
exits "--team without an adapter fails" 2 "$LS" eligible "$Q" "$TLOG" --team api
"$LS" append "$TLOG" TT.03 landed 201 feat/t-03 "$BASE" 1/1 green "MERGE(0)" -
"$LS" append "$TLOG" TT.02 landed 202 feat/t-02 "$BASE" 1/1 green "MERGE(0)" -
eq "a logged head advances its team only" "TT.01" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$TAD" | cut -f1)"
eq "a cross-team dependency still waits" "" \
   "$("$LS" eligible "$Q" "$TLOG" --team web "$TAD")"
"$LS" append "$TLOG" TT.01 landed 203 feat/t-01 "$BASE" 1/1 green "MERGE(0)" -
eq "a team dependency unlocks its dependent" "TT.04" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$TAD" | cut -f1)"
"$LS" append "$TLOG" TT.04 landed 204 feat/t-04 "$BASE" 1/1 green "MERGE(0)" -
eq "the other team's dependency lands and unlocks it" "TT.05" \
   "$("$LS" eligible "$Q" "$TLOG" --team web "$TAD" | cut -f1)"
eq "a drained team prints nothing" "" "$("$LS" eligible "$Q" "$TLOG" --team api "$TAD")"

echo
if [ "$FAIL" -eq 0 ]; then
  printf 'PASS %s/%s\n' "$PASS" "$((PASS+FAIL))"
  exit 0
else
  printf 'FAILED %s of %s\n' "$FAIL" "$((PASS+FAIL))"
  exit 1
fi
