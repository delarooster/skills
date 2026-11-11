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

REPO="$WORK/repo"; Q="$REPO/stories"
G() { git -C "$REPO" "$@"; }

mkdir -p "$REPO/tasks"
AD="$REPO/tasks/story-loop.md"
cat > "$AD" <<'EOF'
# story-loop adapter

| Field | Value |
|---|---|
| Queue root | stories |
| Base branch | develop |
| Stack mode | linear |
| Forge | none |
| CI system | none |
| Merge policy | never |
| Stack policy | none |
| Scratch root | scratch |
EOF

echo "== the adapter drives the run =="
"$LS" adapter-check "$AD" >/dev/null && ok "forge-none adapter validates" || bad "forge-none adapter validates"
BASE=$("$LS" adapter "$AD" 'Base branch')
MODE=$("$LS" adapter "$AD" 'Stack mode')
Q="$REPO/$("$LS" adapter "$AD" 'Queue root')"
chk "base branch comes from the adapter" "develop" "$BASE"
G init -q
G config user.email "story-loop@localhost"
G config user.name  "story-loop selftest"
G config commit.gpgsign false
echo "scratch" > "$REPO/README.md"
G add -A && G commit -qm "root"
G branch -M "$BASE"

mkdir -p "$Q/2_ready"
n=1
for id in YY.01 YY.02 YY.03; do
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
  parent=$("$LS" parent "$LOG" "$BASE" "$MODE" "$deps")
  branch="feat/$(printf '%s' "$id" | tr '.[:upper:]' '-[:lower:]')"

  G switch -q -c "$branch" "$parent"
  scratch="$WORK/$("$LS" adapter "$AD" 'Scratch root')/$id"
  mkdir -p "$scratch" && echo "body for $id" > "$scratch/body.md"
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
chk "chain head is the last branch" "feat/yy-03" "$("$LS" head "$LOG" "$BASE")"
chk "chain depth is 3" "3" "$("$LS" depth "$LOG" "$BASE")"

echo "== git agrees it is a real stack =="
G merge-base --is-ancestor feat/yy-01 feat/yy-02 \
  && ok "yy-02 contains yy-01" || bad "yy-02 contains yy-01"
G merge-base --is-ancestor feat/yy-02 feat/yy-03 \
  && ok "yy-03 contains yy-02" || bad "yy-03 contains yy-02"
chk "the tip carries all three files" "3" \
  "$(G ls-tree --name-only feat/yy-03 | grep -c '^file-')"
chk "the tip is 3 commits ahead of base" "3" \
  "$(G rev-list --count "$BASE"..feat/yy-03)"

# ------------------------------------------------------------- the broken run
echo "== control: what happens with no parent handed in =="
for id in XX.01 XX.02 XX.03; do
  b="broken/$(printf '%s' "$id" | tr '.[:upper:]' '-[:lower:]')"
  G switch -q -c "$b" "$BASE"          # the default an unbriefed worker picks
  echo "work for $id" > "$REPO/broken-$id.txt"
  G add -A && G commit -qm "$id"
done
if G merge-base --is-ancestor broken/xx-01 broken/xx-02 2>/dev/null; then
  bad "unstacked branches should NOT contain each other"
else
  ok "unstacked branches do not contain each other (the bug, reproduced)"
fi
chk "an unstacked tip carries only its own file" "1" \
  "$(G ls-tree --name-only broken/xx-03 | grep -c '^broken-')"

echo "== scratch is per story, never shared =="
chk "each story wrote its own scratch dir" "3" "$(find "$WORK/scratch" -mindepth 1 -maxdepth 1 -type d | grep -c .)"

echo "== merge policy under forge none =="
v=$("$LS" merge-gate "$("$LS" adapter "$AD" 'Merge policy')" MERGE 0 0 green 1/1 no none \
   "$("$LS" adapter "$AD" 'Human-only categories')")
chk "policy never holds even a clean verdict" "hold :: merge policy never" "$v"
sed 's/| Merge policy | never |/| Merge policy | clean-verdict |/' "$AD" > "$WORK/cv.md"
if "$LS" adapter-check "$WORK/cv.md" >/dev/null 2>&1; then
  bad "clean-verdict with no forge must be rejected"
else
  ok "clean-verdict with no forge is rejected"
fi

echo "== and the orchestrator catches it before it is logged =="
if "$LS" check-base feat/yy-03 "$BASE" 2>/dev/null; then
  bad "check-base should reject a base that is not the supplied parent"
else
  ok "check-base rejects the unstacked return"
fi

# ------------------------------------------------------- two-repo workspace
echo "== workspace queue shared by two repos, run from an unrelated cwd =="
WS="$WORK/ws"
mkdir -p "$WS/workspace/tasks/stories/2_ready" "$WS/workspace/tasks/stories/6_completed" "$WORK/elsewhere"
for r in api web; do
  R="$WS/$r"; mkdir -p "$R/tasks"
  git -C "$R" init -q
  git -C "$R" config user.email "story-loop@localhost"; git -C "$R" config user.name "story-loop e2e"
  git -C "$R" config commit.gpgsign false
  echo "$r" > "$R/README.md"; git -C "$R" add -A; git -C "$R" commit -qm root; git -C "$R" branch -M main
  cat > "$R/tasks/story-loop.md" <<'EOF'
| Field | Value |
|---|---|
| Queue root | ../workspace/tasks/stories |
| Log path | ../workspace/tasks/loop-log.md |
| Base branch | main |
| Forge | none |
EOF
done
wstory() { # wstory <file> <id> <repo> <deps>
  printf '# %s: Workspace story\n\n**Repo:** %s\n**Dependencies:** %s\n**Effort:** 1\n' "$2" "$3" "$4" \
    > "$WS/workspace/tasks/stories/$1"
}
wstory 2_ready/V-01.md VV.01 api None
wstory 2_ready/V-02.md VV.02 web VV.01
wstory 2_ready/V-03.md VV.03 api VV.02
wstory 2_ready/V-04.md VV.04 web VV.00
wstory 6_completed/V-00.md VV.00 web None

cd "$WORK/elsewhere" || exit 1
AAD="$WS/api/tasks/story-loop.md"
WQ=$("$LS" adapter-path "$AAD" 'Queue root')
WL=$("$LS" adapter-path "$AAD" 'Log path')
chk "queue root resolves against the adapter's repo, not the cwd" \
  "$(cd "$WS/workspace/tasks/stories" && pwd -P)" "$(cd "$WQ" && pwd -P)"
chk "both member adapters name the same queue" \
  "$(cd "$WQ" && pwd -P)" "$(cd "$("$LS" adapter-path "$WS/web/tasks/story-loop.md" 'Queue root')" && pwd -P)"
chk "an absolute field is left alone" "/abs/x" \
  "$(printf '| Log path | /abs/x |\n' > "$WORK/abs.md"; "$LS" adapter-path "$WORK/abs.md" 'Log path')"
"$LS" init-log "$WL"
chk "index reads the workspace queue" "4" "$("$LS" index "$WQ" | grep -c .)"
chk "completed reads the workspace ledger" "VV.00" "$("$LS" completed "$WQ")"
chk "nothing is stalled" "" "$("$LS" stalled "$WQ" "$WL")"

order=""
while :; do
  line=$("$LS" eligible "$WQ" "$WL"); [ -n "$line" ] || break
  id=$(printf '%s' "$line" | cut -f1); deps=$(printf '%s' "$line" | cut -f2)
  repo=$("$LS" repo "$(printf '%s' "$line" | cut -f4)")
  RAD="$WS/$repo/tasks/story-loop.md"
  base=$("$LS" adapter "$RAD" 'Base branch')
  parent=$("$LS" parent "$WL" "$base" linear "$deps" "$repo")
  branch="feat/$(printf '%s' "$id" | tr '.[:upper:]' '-[:lower:]')"
  git -C "$WS/$repo" switch -q -c "$branch" "$parent"
  echo "$id" > "$WS/$repo/$id.txt"; git -C "$WS/$repo" add -A; git -C "$WS/$repo" commit -qm "$id"
  "$LS" append "$WL" "$id" landed - "$repo:$branch" "$parent" 1/1 absent - -
  order="$order $id"
done
cd "$HERE" || exit 1

chk "every story ran, dependency order kept" " VV.01 VV.02 VV.03 VV.04" "$order"
chk "VV.03 stacks on its own repo's head, not the web branch" "feat/vv-01" \
  "$(awk -F'|' '$2 ~ /VV.03/ {gsub(/ /,"",$6); print $6}' "$WL")"
chk "VV.02's api dependency is not a git parent in web" "main" \
  "$(awk -F'|' '$2 ~ /VV.02/ {gsub(/ /,"",$6); print $6}' "$WL")"
git -C "$WS/api" merge-base --is-ancestor feat/vv-01 feat/vv-03 \
  && ok "api: vv-03 contains vv-01" || bad "api: vv-03 contains vv-01"
chk "api head read from the shared log" "feat/vv-03" "$("$LS" head "$WL" main api)"
chk "web depth counts only web" "2" "$("$LS" depth "$WL" main web)"

echo
printf 'repo was %s (removed on exit)\n' "$REPO"
if [ "$FAIL" -eq 0 ]; then printf 'PASS %s/%s\n' "$PASS" "$((PASS+FAIL))"; exit 0
else printf 'FAILED %s of %s\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
