#!/usr/bin/env bash
# anchor-check.sh -- keep the code anchors that stories cite honest. Run from the repo root.
#
#   paths [rev|WT]   story<TAB>path for every backtick-quoted source path, :N suffix stripped
#   lost <rev>       paths the working tree stopped naming, relative to <rev>
#   resolve          run every `git grep` a story quotes above its acceptance criteria
#
# Configuration, all optional:
#   ANCHOR_CHECK_DIR      story root                      (tasks/stories)
#   ANCHOR_CHECK_GLOB     space-separated filename globs  (*.md)
#   ANCHOR_CHECK_EXCLUDE  space-separated filename globs  (README.md)
#   ANCHOR_CHECK_EXTS     pipe-separated file extensions  (a broad source list, below)
#   ANCHOR_CHECK_AC       acceptance-criteria heading     (Acceptance criteria)
set -uo pipefail

STORIES_DIR="${ANCHOR_CHECK_DIR:-tasks/stories}"
GLOBS="${ANCHOR_CHECK_GLOB:-*.md}"
EXCLUDE="${ANCHOR_CHECK_EXCLUDE:-README.md}"
EXTS="${ANCHOR_CHECK_EXTS:-ts|tsx|js|jsx|mjs|svelte|vue|py|go|rs|java|kt|cs|csproj|razor|rb|php|sh|sql|tf|bicep|yml|yaml|json|toml|md|config}"
AC_HEADING="${ANCHOR_CHECK_AC:-Acceptance criteria}"
FILE_RE="[A-Za-z0-9_./+-]+\.($EXTS)(:[0-9]+(-[0-9]+)?)?"

STORIES=()
_collect() {
  local g f base x skip
  set -f
  for g in $GLOBS; do
    set +f
    while IFS= read -r f; do
      base=$(basename "$f"); skip=0
      set -f
      for x in $EXCLUDE; do
        # shellcheck disable=SC2254
        case "$base" in $x) skip=1 ;; esac
      done
      set +f
      [ "$skip" = 1 ] || printf '%s\n' "$f"
    done < <(find "$STORIES_DIR" -type f -name "$g" 2>/dev/null)
    set -f
  done
  set +f
}
while IFS= read -r f; do [ -n "$f" ] && STORIES+=("$f"); done < <(_collect | sort -u)
if [ "${#STORIES[@]}" -eq 0 ]; then
  echo "anchor-check: no stories matching '$GLOBS' under $STORIES_DIR; refusing to report on an empty corpus" >&2
  exit 3
fi

# Backtick-quoted means both forms markdown offers: inline spans and fenced blocks.
paths() {
  local rev="${1:-WT}" f body
  for f in "${STORIES[@]}"; do
    if [ "$rev" = WT ]; then body=$(cat "$f"); else body=$(git show "$rev:$f" 2>/dev/null); fi
    [ -n "$body" ] || continue
    {
      printf '%s\n' "$body" | grep -o -E '`[^`]+`' | tr -d '`'
      printf '%s\n' "$body" | awk '/^```/ {fence = !fence; next} fence'
    } \
      | grep -o -E "$FILE_RE" \
      | sed -E 's/:[0-9]+(-[0-9]+)?$//' \
      | sort -u \
      | sed "s|^|$(basename "$f")	|"
  done
}

# A path is retained when the same story now names a longer path ending in it:
# `src/x.ts` -> `app/src/x.ts` is a sharpening, not a deletion.
lost() {
  local rev="$1" before after line story path rc=0 n=0
  before=$(paths "$rev" | sort -u)
  after=$(paths WT | sort -u)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    story=${line%%$'\t'*}; path=${line#*$'\t'}
    if printf '%s\n' "$after" | grep -q -- "^$story"$'\t'".*$(printf '%s' "$path" | sed 's/[.[\*^$]/\\&/g')\$"; then
      continue
    fi
    n=$((n + 1)); rc=1
    printf 'LOST  %s  %s\n' "$story" "$path"
  done < <(comm -23 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
  printf 'paths before: %d  after: %d  lost: %d\n' \
    "$(printf '%s\n' "$before" | grep -c .)" "$(printf '%s\n' "$after" | grep -c .)" "$n"
  return $rc
}

# A grep above the acceptance criteria cites code that exists now and must hit; one at
# or below asserts the post-story state and is only counted. `[historical]` right after
# an anchor, same line, skips it. An absence claim must follow the anchor, not precede it.
NEGATIVE_RE='returns nothing|returns no |shows no |finds nothing|finds no |is empty|nothing at HEAD|nothing anywhere'

# Anchors are parsed, never executed through a shell. Grammar:
#   git grep [FLAGS] PATTERN [--] [PATHSPEC...]
#   git grep [FLAGS] -e PATTERN [--] [PATHSPEC...]
# FLAGS come from an allow-list; a pathspec may not start with '-'; `$`, backticks
# and unquoted shell operators void the anchor. The result always runs as
#   git grep FLAGS -e PATTERN -- PATHSPEC...
SAFE_FLAGS='niwEFPIlch'
TOKENS=(); GREP_ARGS=(); WHY=""

_tokenize() {
  local s="$1" i=0 c tok="" in=0 q="" n=${#1}
  TOKENS=()
  while [ "$i" -lt "$n" ]; do
    c=${s:$i:1}
    if [ "$q" = "'" ]; then
      if [ "$c" = "'" ]; then q=""; else tok="$tok$c"; fi
    elif [ "$q" = '"' ]; then
      case "$c" in
        '"') q="" ;;
        '$'|'`') WHY="expansion inside double quotes"; return 1 ;;
        '\') i=$((i + 1)); tok="$tok${s:$i:1}" ;;
        *) tok="$tok$c" ;;
      esac
    else
      case "$c" in
        ' '|'	') [ "$in" = 1 ] && TOKENS+=("$tok"); tok=""; in=0; i=$((i + 1)); continue ;;
        "'"|'"') q="$c" ;;
        '\') i=$((i + 1)); tok="$tok${s:$i:1}" ;;
        '$'|'`'|';'|'|'|'&'|'<'|'>'|'('|')') WHY="shell syntax '$c'"; return 1 ;;
        *) tok="$tok$c" ;;
      esac
    fi
    in=1; i=$((i + 1))
  done
  [ -z "$q" ] || { WHY="unterminated quote"; return 1; }
  [ "$in" = 1 ] && TOKENS+=("$tok")
  return 0
}

_parse_anchor() {
  local t pat="" have=0 dashdash=0 flags=() paths=() i=0
  WHY=""; GREP_ARGS=()
  _tokenize "$1" || return 1
  [ "${#TOKENS[@]}" -ge 3 ] && [ "${TOKENS[0]}" = git ] && [ "${TOKENS[1]}" = grep ] \
    || { WHY="not a git grep"; return 1; }
  for t in "${TOKENS[@]:2}"; do
    if [ "$have" = 0 ]; then
      if [ "$i" = e ]; then pat="$t"; have=1; i=0; continue; fi
      case "$t" in
        -e) i=e ;;
        --) WHY="'--' before a pattern"; return 1 ;;
        -?*) case "${t#-}" in *[!$SAFE_FLAGS]*) WHY="flag '$t' not allowed"; return 1 ;; esac
             flags+=("$t") ;;
        *) pat="$t"; have=1 ;;
      esac
    else
      if [ "$t" = -- ] && [ "$dashdash" = 0 ] && [ "${#paths[@]}" = 0 ]; then dashdash=1; continue; fi
      case "$t" in -*) WHY="pathspec '$t' starts with '-'"; return 1 ;; esac
      paths+=("$t")
    fi
  done
  [ "$have" = 1 ] && [ -n "$pat" ] || { WHY="no pattern"; return 1; }
  GREP_ARGS=(${flags[@]+"${flags[@]}"} -e "$pat" -- ${paths[@]+"${paths[@]}"})
}

resolve() {
  local rc=0 pos=0 zero=0 neg=0 negbad=0 fut=0 hist=0 bad=0 f n cmd out ctx ac line
  while IFS= read -r line; do
    f=${line%%:*}; line=${line#*:}
    n=${line%%:*}; cmd=${line#*:}
    ac=$(grep -in "^## $AC_HEADING" "$f" | head -1 | cut -d: -f1)
    if [ -n "$ac" ] && [ "$n" -ge "$ac" ]; then
      fut=$((fut + 1)); continue
    fi
    ctx=$(sed -n "${n}p;$((n + 1))p" "$f" | sed -e "s/.*$(printf '%s' "$cmd" | sed 's/[][\\.*^$/]/\\&/g')\`//" -e 's/[*_]//g')
    if printf '%s\n' "$ctx" | head -1 | grep -qF '[historical]'; then
      hist=$((hist + 1)); continue
    fi
    if ! _parse_anchor "$cmd"; then
      bad=$((bad + 1)); rc=1
      printf 'INVALID ANCHOR  %s  (%s)\n  %s\n' "$(basename "$f")" "$WHY" "$cmd"
      continue
    fi
    out=$(git grep "${GREP_ARGS[@]}" 2>&1)
    if printf '%s' "$ctx" | grep -qE "$NEGATIVE_RE"; then
      neg=$((neg + 1))
      if [ -n "$out" ]; then
        negbad=$((negbad + 1)); rc=1
        printf 'ASSERTED-ABSENT ANCHOR HITS  %s\n  %s\n' "$(basename "$f")" "$cmd"
      fi
      continue
    fi
    pos=$((pos + 1))
    if [ -z "$out" ]; then
      zero=$((zero + 1)); rc=1
      printf 'ZERO HITS  %s\n           %s\n' "$(basename "$f")" "$cmd"
    fi
  done < <(
    grep -o -nH -E '`git grep [^`]+`' "${STORIES[@]}" | sed -E 's/`//g'
  )
  printf 'description anchors: %d positive (%d zero-hit), %d asserted-absent (%d wrong), %d invalid; %d in criteria, not run; %d marked [historical], skipped\n' \
    "$pos" "$zero" "$neg" "$negbad" "$bad" "$fut" "$hist"
  return $rc
}

case "${1:-}" in
  paths) paths "${2:-WT}" ;;
  lost) lost "${2:?usage: $0 lost <rev>}" ;;
  resolve) resolve ;;
  *) echo "usage: $0 paths [rev] | lost <rev> | resolve" >&2; exit 2 ;;
esac
