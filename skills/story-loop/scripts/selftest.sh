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

story 2_ready   Z-01-first.md  Z.01 None  1
story 1_backlog Z-02-second.md Z.02 None  2
story 1_backlog Z-03-third.md  Z.03 Z.02  3
story 1_backlog Z-04-dependent-on-blocked.md Z.04 Z.09 1
# a story parked in a non-queue folder must not be picked up
story 3_in-progress Z-99-inflight.md Z.99 None 1

echo "== index and read-nothing discipline =="
"$LS" init-log "$LOG"
eq "log header written" "| Story | Outcome | PR | Branch | Base | AC | CI | Verdict | Notes |" \
   "$(sed -n '3p' "$LOG")"
IDX=$("$LS" index "$Q")
eq "index finds 4 queue stories" "4" "$(printf '%s\n' "$IDX" | grep -c .)"
eq "2_ready sorts before 1_backlog" "Z.01" "$(printf '%s\n' "$IDX" | head -1 | cut -f1)"
eq "parses declared dependency" "Z.02" "$(printf '%s\n' "$IDX" | awk -F'\t' '$1=="Z.03"{print $2}')"
eq "parses effort" "2" "$(printf '%s\n' "$IDX" | awk -F'\t' '$1=="Z.02"{print $3}')"
eq "in-progress story is not a queue member" "" \
   "$(printf '%s\n' "$IDX" | awk -F'\t' '$1=="Z.99"{print $1}')"
if printf '%s\n' "$IDX" | grep -q SENTINEL_BODY_TEXT; then
  bad "index never emits story body" "no body text" "body text leaked"
else
  ok "index never emits story body"
fi

echo "== chain head on a cold start =="
eq "empty log: head is the base" "$BASE" "$("$LS" head "$LOG" "$BASE")"
eq "empty log: depth 0" "0" "$("$LS" depth "$LOG" "$BASE")"
eq "first eligible is Z.01" "Z.01" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "Z.01 parent is the base" "$BASE" "$("$LS" parent "$LOG" "$BASE" linear None)"

echo "== pending dependencies are not stalled dependencies =="
# Z.03 depends on Z.02, which is still queued. That is a wait, not a block.
eq "a dependency still in the queue is pending, not stalled" "" \
   "$("$LS" stalled "$Q" "$LOG" | awk -F'\t' '$1=="Z.03"{print $1}')"

echo "== stacking: the bug this exists to prevent =="
"$LS" append "$LOG" Z.01 landed 101 feat/z-01 "$BASE" 1/1 green PASS -
eq "head advances to the landed branch" "feat/z-01" "$("$LS" head "$LOG" "$BASE")"
eq "next story is Z.02" "Z.02" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "linear: independent story stacks on head" "feat/z-01" \
   "$("$LS" parent "$LOG" "$BASE" linear None)"
eq "dag: independent story roots at base" "$BASE" \
   "$("$LS" parent "$LOG" "$BASE" dag None)"

"$LS" append "$LOG" Z.02 landed 102 feat/z-02 feat/z-01 2/2 green PASS -
eq "declared dependency picks its branch, not the head" "feat/z-02" \
   "$("$LS" parent "$LOG" "$BASE" linear Z.02)"
eq "depth counts the chain" "2" "$("$LS" depth "$LOG" "$BASE")"

echo "== blocked rows must not corrupt the chain =="
"$LS" append "$LOG" Z.03 blocked - - - 0/3 absent HOLD "underspecified"
eq "blocked row does not advance the head" "feat/z-02" "$("$LS" head "$LOG" "$BASE")"
eq "blocked row does not count toward depth" "2" "$("$LS" depth "$LOG" "$BASE")"
eq "outcome reads back" "blocked" "$("$LS" outcome "$LOG" Z.03)"

echo "== a story must never be silently skipped =="
# Z.04 depends on Z.09, which is in neither the queue nor the log. It can never
# become eligible. If the loop only asked "what is eligible?" the queue would
# look drained while Z.04 vanished unlogged.
eq "unsatisfiable story is not eligible" "" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "but it IS reported as stalled" "Z.04" "$("$LS" stalled "$Q" "$LOG" | cut -f1)"
eq "with the dependency that can never be met" "Z.09" "$("$LS" stalled "$Q" "$LOG" | cut -f2)"
"$LS" append "$LOG" Z.04 blocked - - - 0/1 absent HOLD "dep Z.09 unsatisfiable"
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
story 6_completed z-20.md Z.20 None 1
story 6_completed z-22.md Z.22 None 1
story 6_completed z-23.md Z.23 None 1
story 1_backlog   z-21.md Z.21 Z.20 2
eq "6_completed is still not a queue member" "" \
   "$("$LS" index "$Q" | awk -F'\t' '$1=="Z.20"{print $1}')"
eq "the completed ledger sees all three" "Z.20 Z.22 Z.23" \
   "$("$LS" completed "$Q" | tr '\n' ' ' | sed 's/ $//')"
eq "a match on the FIRST line is found, not lost to SIGPIPE" "Z.21" \
   "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "its dependent becomes eligible" "Z.21" "$("$LS" eligible "$Q" "$LOG" | cut -f1)"
eq "and is never reported stalled" "" \
   "$("$LS" stalled "$Q" "$LOG" | awk -F'\t' '$1=="Z.21"{print $1}')"
eq "a merged dependency roots at the base, not a stale branch" "$BASE" \
   "$("$LS" parent "$LOG" "$BASE" linear Z.20)"

echo "== unstacked detection =="
exits "matching base passes" 0 "$LS" check-base feat/z-02 feat/z-02
exits "mismatched base fails"  1 "$LS" check-base feat/z-02 "$BASE"

echo "== cold start from the log alone =="
# Same assertions, fresh process, no memory of the run above.
eq "head survives a restart" "feat/z-02" "$("$LS" head "$LOG" "$BASE")"
eq "a resumed story stacks on the chain, not the base" "feat/z-02" \
   "$("$LS" parent "$LOG" "$BASE" linear None)"

echo "== teams: per-team heads from the adapter's Teams table =="
Q="$WORK/teams"; TLOG="$WORK/teams-log.md"; AD="$WORK/story-loop.md"
mkdir -p "$Q/1_backlog" "$Q/2_ready" "$Q/6_completed"
story 2_ready     t-01.md T.01 None 1
story 2_ready     t-02.md T.02 None 1
story 1_backlog   t-03.md T.03 None 1
story 1_backlog   t-04.md T.04 T.01 1
story 1_backlog   t-05.md T.05 T.04 1
story 6_completed t-00.md T.00 None 1
cat > "$AD" <<'EOF'
# story-loop adapter

| Field | Value |
|---|---|
| Base branch | develop |
| Lanes | 1 |

## Teams

| Team | Surface | Stories |
|---|---|---|
| api | server | T.03, T.01, T.04 |
| web | client | T.00 T.02,T.05 |

| Other | Table |
|---|---|
| zz | T.99 |
EOF
"$LS" init-log "$TLOG"
eq "teams lists both teams and stops at the table end" "2" "$("$LS" teams "$AD" | grep -c .)"
eq "teams joins ids in table order" "$(printf 'api\tT.03,T.01,T.04')" \
   "$("$LS" teams "$AD" | head -1)"
eq "teams accepts spaces and commas as separators" "$(printf 'web\tT.00,T.02,T.05')" \
   "$("$LS" teams "$AD" | sed -n 2p)"
eq "an adapter without Teams lists none" "" "$("$LS" teams "$WORK/loop-log.md")"
exits "teams without an adapter fails" 2 "$LS" teams "$WORK/missing.md"
eq "unfiltered eligible keeps queue order" "T.01" "$("$LS" eligible "$Q" "$TLOG" | cut -f1)"
eq "team order beats queue order" "T.03" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$AD" | cut -f1)"
eq "team output keeps the index shape" "4" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$AD" | awk -F'\t' '{print NF}')"
eq "a listed story outside the queue is skipped" "T.02" \
   "$("$LS" eligible "$Q" "$TLOG" --team web "$AD" | cut -f1)"
exits "unknown team fails" 2 "$LS" eligible "$Q" "$TLOG" --team ops "$AD"
exits "--team without an adapter fails" 2 "$LS" eligible "$Q" "$TLOG" --team api
"$LS" append "$TLOG" T.03 landed 201 feat/t-03 "$BASE" 1/1 green "MERGE(0)" -
"$LS" append "$TLOG" T.02 landed 202 feat/t-02 "$BASE" 1/1 green "MERGE(0)" -
eq "a logged head advances its team only" "T.01" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$AD" | cut -f1)"
eq "a cross-team dependency still waits" "" \
   "$("$LS" eligible "$Q" "$TLOG" --team web "$AD")"
"$LS" append "$TLOG" T.01 landed 203 feat/t-01 "$BASE" 1/1 green "MERGE(0)" -
eq "a team dependency unlocks its dependent" "T.04" \
   "$("$LS" eligible "$Q" "$TLOG" --team api "$AD" | cut -f1)"
"$LS" append "$TLOG" T.04 landed 204 feat/t-04 "$BASE" 1/1 green "MERGE(0)" -
eq "the other team's dependency lands and unlocks it" "T.05" \
   "$("$LS" eligible "$Q" "$TLOG" --team web "$AD" | cut -f1)"
eq "a drained team prints nothing" "" "$("$LS" eligible "$Q" "$TLOG" --team api "$AD")"

echo
if [ "$FAIL" -eq 0 ]; then
  printf 'PASS %s/%s\n' "$PASS" "$((PASS+FAIL))"
  exit 0
else
  printf 'FAILED %s of %s\n' "$FAIL" "$((PASS+FAIL))"
  exit 1
fi
