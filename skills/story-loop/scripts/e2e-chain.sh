#!/usr/bin/env bash
# e2e-chain.sh -- prove the parent computation produces a real git stack.
#
# Runs the loop's git half against a throwaway repository under $TMPDIR: no
# remote, no pull requests, no network, and nothing outside its own temp dir.
# This is the "forge: none" mode of /story-loop, which is why it can be run
# unattended as a smoke test.
#
# It builds the chain twice: once the correct way (branch from the computed
# parent) and once the broken way (branch from base every time, which is what an
# implementer does when nobody hands it a parent). Then it asserts the difference
# with git itself.
#
#   skills/story-loop/scripts/e2e-chain.sh

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
LS="$HERE/loop-state.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/story-loop-e2e.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
chk() { if [ "$2" = "$3" ]; then ok "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fi; }

REPO="$WORK/repo"; Q="$REPO/stories"; BASE="develop"
G() { git -C "$REPO" "$@"; }

mkdir -p "$REPO"
G init -q
G config user.email "story-loop@localhost"
G config user.name  "story-loop selftest"
G config commit.gpgsign false
echo "scratch" > "$REPO/README.md"
G add -A && G commit -qm "root"
G branch -M "$BASE"

mkdir -p "$Q/2_ready"
n=1
for id in Y.01 Y.02 Y.03; do
  cat > "$Q/2_ready/Y-0$n-story.md" <<EOF
# $id: Scratch story $id

**Epic:** Y
**Effort:** 1
**Dependencies:** None
**Skillsets:** none

## Acceptance Criteria

- [ ] touches file-$n
EOF
  n=$((n+1))
done

# ---------------------------------------------------------------- correct run
LOG="$WORK/loop-log.md"
"$LS" init-log "$LOG"

echo "== drain the queue, stacking each story on the computed parent =="
i=1
while :; do
  line=$("$LS" eligible "$Q" "$LOG")
  [ -n "$line" ] || break
  id=$(printf '%s' "$line" | cut -f1)
  deps=$(printf '%s' "$line" | cut -f2)

  # This is the whole fix: the parent is computed here, by the orchestrator,
  # and handed to the worker. The worker never chooses it.
  parent=$("$LS" parent "$LOG" "$BASE" linear "$deps")
  branch="feat/$(printf '%s' "$id" | tr '.[:upper:]' '-[:lower:]')"

  G switch -q -c "$branch" "$parent"
  echo "work for $id" > "$REPO/file-$i.txt"
  G add -A && G commit -qm "$id: add file-$i"

  # What the implementer reports back, and the check the orchestrator runs on it.
  returned_base="$parent"
  if "$LS" check-base "$parent" "$returned_base" 2>/dev/null; then
    "$LS" append "$LOG" "$id" landed - "$branch" "$parent" 1/1 absent - -
  else
    "$LS" append "$LOG" "$id" blocked - "$branch" "$returned_base" 0/1 absent - unstacked
  fi
  printf '     %s -> branch %s on parent %s\n' "$id" "$branch" "$parent"
  i=$((i+1))
done

chk "three stories landed" "3" "$(grep -c '| landed |' "$LOG")"
chk "chain head is the last branch" "feat/y-03" "$("$LS" head "$LOG" "$BASE")"
chk "chain depth is 3" "3" "$("$LS" depth "$LOG" "$BASE")"

echo "== git agrees it is a real stack =="
G merge-base --is-ancestor feat/y-01 feat/y-02 \
  && ok "y-02 contains y-01" || bad "y-02 contains y-01"
G merge-base --is-ancestor feat/y-02 feat/y-03 \
  && ok "y-03 contains y-02" || bad "y-03 contains y-02"
chk "the tip carries all three files" "3" \
  "$(G ls-tree --name-only feat/y-03 | grep -c '^file-')"
chk "the tip is 3 commits ahead of base" "3" \
  "$(G rev-list --count "$BASE"..feat/y-03)"

# ------------------------------------------------------------- the broken run
echo "== control: what happens with no parent handed in =="
for id in X.01 X.02 X.03; do
  b="broken/$(printf '%s' "$id" | tr '.[:upper:]' '-[:lower:]')"
  G switch -q -c "$b" "$BASE"          # the default an unbriefed worker picks
  echo "work for $id" > "$REPO/broken-$id.txt"
  G add -A && G commit -qm "$id"
done
if G merge-base --is-ancestor broken/x-01 broken/x-02 2>/dev/null; then
  bad "unstacked branches should NOT contain each other"
else
  ok "unstacked branches do not contain each other (the bug, reproduced)"
fi
chk "an unstacked tip carries only its own file" "1" \
  "$(G ls-tree --name-only broken/x-03 | grep -c '^broken-')"

echo "== and the orchestrator catches it before it is logged =="
if "$LS" check-base feat/y-03 "$BASE" 2>/dev/null; then
  bad "check-base should reject a base that is not the supplied parent"
else
  ok "check-base rejects the unstacked return"
fi

echo
printf 'repo was %s (removed on exit)\n' "$REPO"
if [ "$FAIL" -eq 0 ]; then printf 'PASS %s/%s\n' "$PASS" "$((PASS+FAIL))"; exit 0
else printf 'FAILED %s of %s\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
