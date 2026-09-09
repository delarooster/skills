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

echo "== unstacked detection =="
exits "matching base passes" 0 "$LS" check-base feat/z-02 feat/z-02
exits "mismatched base fails"  1 "$LS" check-base feat/z-02 "$BASE"

echo "== cold start from the log alone =="
# Same assertions, fresh process, no memory of the run above.
eq "head survives a restart" "feat/z-02" "$("$LS" head "$LOG" "$BASE")"
eq "a resumed story stacks on the chain, not the base" "feat/z-02" \
   "$("$LS" parent "$LOG" "$BASE" linear None)"

echo
if [ "$FAIL" -eq 0 ]; then
  printf 'PASS %s/%s\n' "$PASS" "$((PASS+FAIL))"
  exit 0
else
  printf 'FAILED %s of %s\n' "$FAIL" "$((PASS+FAIL))"
  exit 1
fi
