#!/usr/bin/env bash
# anchor-selftest.sh -- exercise anchor-check.sh against a throwaway git repo.
#
#   skills/story-loop/scripts/anchor-selftest.sh

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
AC="$HERE/anchor-check.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/story-loop-anchor.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }
code() { (cd "$REPO" && "$@" >/dev/null 2>&1); echo $?; }

REPO="$WORK/repo"
G() { git -C "$REPO" "$@"; }
mkdir -p "$REPO/src" "$REPO/tasks/stories/1_backlog" "$REPO/plans"
G init -q
G config user.email "anchor@localhost"; G config user.name "anchor selftest"; G config commit.gpgsign false
printf 'export function loadWidget() {}\n' > "$REPO/src/widget.ts"
printf 'def run():\n    pass\n' > "$REPO/src/job.py"

cat > "$REPO/tasks/stories/1_backlog/S-01-widget.md" <<'EOF'
# SS.01: Widget

Touches `src/widget.ts:1` and `src/job.py`.
Anchor: `git grep -n 'loadWidget' -- src`

Gone: `git grep -n 'unloadWidget' -- src` returns nothing.

Removed: `git grep -n 'oldThing'` [historical]

## Acceptance criteria

- [ ] `git grep -n 'newThing'` finds the new code
EOF
cat > "$REPO/tasks/stories/README.md" <<'EOF'
Example: `git grep -n 'doesNotExist'`
EOF
G add -A && G commit -qm root

echo "== paths =="
P=$(cd "$REPO" && "$AC" paths)
eq "extracts both cited paths" "2" "$(printf '%s\n' "$P" | grep -c .)"
eq "strips the line suffix" "1" "$(printf '%s\n' "$P" | grep -c 'src/widget.ts$')"
eq "README is excluded by default" "0" "$(printf '%s\n' "$P" | grep -c README)"
eq "extensions are configurable" "1" \
   "$(cd "$REPO" && ANCHOR_CHECK_EXTS=py "$AC" paths | grep -c .)"

echo "== resolve =="
R=$(cd "$REPO" && "$AC" resolve)
eq "all anchors classified" \
   "description anchors: 1 positive (0 zero-hit), 1 asserted-absent (0 wrong), 0 invalid; 1 in criteria, not run; 1 marked [historical], skipped" \
   "$(printf '%s\n' "$R" | tail -1)"
eq "a healthy corpus exits 0" "0" "$(code "$AC" resolve)"
sed -i.bak 's/loadWidget/renamedWidget/' "$REPO/src/widget.ts"
eq "a renamed symbol is a zero-hit anchor" "1" "$(code "$AC" resolve)"
mv "$REPO/src/widget.ts.bak" "$REPO/src/widget.ts"
printf 'function unloadWidget() {}\n' >> "$REPO/src/widget.ts"
eq "an asserted absence that hits fails" "1" "$(code "$AC" resolve)"
G checkout -q -- src/widget.ts

echo "== a story cannot run code =="
E="$WORK/executed"
payloads=(
  "git grep --open-files-in-pager='touch $E' loadWidget"
  "git grep -O'touch $E' loadWidget"
  "git grep --exec='touch $E' loadWidget"
  "git grep --no-index loadWidget $WORK"
  "git grep -n \$(touch $E) -- src"
  "git grep -n \"\$(touch $E)\" -- src"
  "git grep -n x; touch $E"
  "git grep -n loadWidget -- src --open-files-in-pager=touch"
  "git grep -n loadWidget -O touch"
)
k=0
for pl in "${payloads[@]}"; do
  k=$((k + 1))
  printf '# SS.9%s: Hostile\n\nAnchor: `%s`\n' "$k" "$pl" > "$REPO/tasks/stories/1_backlog/S-9$k-hostile.md"
  out=$(cd "$REPO" && ANCHOR_CHECK_GLOB="S-9$k-*.md" "$AC" resolve 2>&1); rc=$?
  label=$(printf '%s' "$pl" | cut -c 10-40)
  if [ -e "$E" ]; then bad "no execution: $label" "no file" "file created"; rm -f "$E"
  else ok "no execution: $label"; fi
  if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q '^INVALID ANCHOR'; then ok "reported invalid: $label"
  else bad "reported invalid: $label" "INVALID ANCHOR, exit 1" "exit $rc: $(printf '%s' "$out" | tail -1)"; fi
  rm -f "$REPO/tasks/stories/1_backlog/S-9$k-hostile.md"
done

echo "== legitimate anchor forms still run =="
printf -- '-foo = 1\n' > "$REPO/src/dash.txt"; G add -A; G commit -qm dash
legit() { # legit <label> <anchor>
  printf '# SS.80: Fine\n\nAnchor: `%s`\n' "$2" > "$REPO/tasks/stories/1_backlog/S-80-fine.md"
  eq "$1" "0" "$(code env ANCHOR_CHECK_GLOB='S-80-*.md' "$AC" resolve)"
}
legit "a leading-dash pattern via -e"          "git grep -n -e '-foo' -- src"
legit "combined allowed flags"                 "git grep -nwF 'loadWidget' -- src"
legit "no pathspec"                            "git grep -n loadWidget"
legit "double-quoted pattern"                  'git grep -n "load[A-Z]idget" -- src/widget.ts'
legit "several pathspecs"                      "git grep -n loadWidget -- src docs"
rm -f "$REPO/tasks/stories/1_backlog/S-80-fine.md"

echo "== lost =="
sed -i.bak 's|`src/job.py`|`app/src/job.py`|' "$REPO/tasks/stories/1_backlog/S-01-widget.md"
eq "a sharpened path is retained" "0" "$(code "$AC" lost HEAD)"
sed -i.bak 's| and `app/src/job.py`||' "$REPO/tasks/stories/1_backlog/S-01-widget.md"
eq "a dropped path is lost" "1" "$(code "$AC" lost HEAD)"
rm -f "$REPO"/tasks/stories/1_backlog/*.bak

echo "== configuration =="
cp "$REPO/tasks/stories/1_backlog/S-01-widget.md" "$REPO/plans/P-01.story"
eq "a custom dir and glob find the story" "0" \
   "$(code env ANCHOR_CHECK_DIR=plans ANCHOR_CHECK_GLOB='*.story' "$AC" resolve)"
eq "an empty corpus refuses to report" "3" \
   "$(code env ANCHOR_CHECK_DIR=plans ANCHOR_CHECK_GLOB='Q-*.md' "$AC" resolve)"
eq "no command is a usage error" "2" "$(code "$AC")"

echo
if [ "$FAIL" -eq 0 ]; then printf 'PASS %s/%s\n' "$PASS" "$((PASS+FAIL))"; exit 0
else printf 'FAILED %s of %s\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
