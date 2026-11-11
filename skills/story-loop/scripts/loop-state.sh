#!/usr/bin/env bash
# loop-state.sh -- deterministic state for /story-loop.
#
# The orchestrator MUST NOT read story bodies, diffs or verdicts. Every decision
# it is allowed to make is derivable from story headers and the log, so every one
# of them lives here instead of in the model's head. Calling these subcommands is
# what keeps the orchestrator's context flat across a long queue.
#
# Portable to bash 3.2 (macOS stock). No associative arrays, no mapfile.

set -uo pipefail

LOG_COLS=9   # Story | Outcome | PR | Branch | Base | AC | CI | Verdict | Notes

usage() {
  cat <<'EOF'
Usage: loop-state.sh <command> [args]

  init-log <log>                          Create a log with the header row
  index <queue-root>                      List queue stories: id<TAB>deps<TAB>effort<TAB>path
  completed <queue-root>                  List ids in 6_completed, one per line
  logged <log> <id>                       Exit 0 if the story has a row
  outcome <log> <id>                      Print a story's outcome, or nothing
  head <log> <base> [repo]                Print the chain head branch
  eligible <queue-root> <log> [--team <name> <adapter>]
                                          Print the next eligible story, or nothing;
                                          --team limits it to that team, in table order
  teams <adapter>                         List the adapter's teams: team<TAB>id,id,...
  stalled <queue-root> <log>              List stories whose dependencies can never be met
  parent <log> <base> <mode> <deps> [repo] Print the parent branch for a story
  check-base <expected> <actual>          Exit 0 if they match, 1 and a message if not
  native-stack <forge> <mode> <teams:yes|no> <parent> <base>
                                          Print link or skip :: <reason>; invalid input exits 2
  depth <log> <base> [repo]               Print the current chain depth
  append <log> <9 fields...>              Append one row
  categories <story>                      Print the story's Categories header, or none
  paths <story>                           Print the story's Paths header, or none
  repo <story>                            Print the story's Repo header, or none
  adapter <file> <field>                  Print one adapter field, default applied
  adapter-raw <file> <field>              Print the value the adapter states, alias included; empty if unset
  adapter-path <file> <field>             Print a path field resolved against the adapter's repo root
  adapter-check <file>                    Print field<TAB>value for every field; exit 1 if invalid
  command <file> <column> [path]          Print the command for a path, from ## Commands or the field
  repo-path <file> <repo>                 Print a workspace repo's checkout from ## Repos
  merge-gate <policy> <verdict> <blocking> <escalation> <ci> <ac> <forwarded>
             <categories> <human-only>    Print merge, or hold :: <reason> and exit 1

Queue order is 2_ready before 1_backlog. Stories in any other state folder are
not queue members. mode is linear or dag.
EOF
}

# --- table helpers -----------------------------------------------------------

_trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# Emit data rows as tab-separated fields. Skips the header and separator rows so
# callers never have to know the table shape.
_rows() {
  local log="$1"
  [ -f "$log" ] || return 0
  awk -F'|' '
    /^[[:space:]]*\|/ {
      n = split($0, f, "|")
      if (n < 3) next
      c1 = f[2]; gsub(/^[ \t]+|[ \t]+$/, "", c1)
      if (c1 == "Story" || c1 == "" ) next          # header or blank id
      if (c1 ~ /^-+$/) next                          # separator
      out = ""
      for (i = 2; i <= n - 1; i++) {
        v = f[i]; gsub(/^[ \t]+|[ \t]+$/, "", v)
        out = out (i == 2 ? "" : "\t") v
      }
      print out
    }
  ' "$log"
}

_field() { printf '%s' "$1" | cut -f"$2"; }

# Membership test for a newline-separated list.
#
# `producer | grep -qxF needle` looks equivalent and is not. grep -q exits the
# moment it matches, closing the pipe; the producer then dies on SIGPIPE, and
# `set -o pipefail` promotes that to exit 141 for the whole pipeline. The test
# reports "absent" for anything that matches before the last line -- silently,
# because there is no `set -e` here. Materialise the list, then search it.
_has_line() { # _has_line <needle> <list>
  grep -qxF "$1" <<EOF
$2
EOF
}

# Story id: the leading token of the first "# " heading, else the filename stem.
# One definition, because index and completed must agree on what an id is or a
# dependency silently stops matching itself. _story_meta reads every file given in
# one awk and prints id, dependencies, effort and path tab-separated, in argument
# order, with the defaults the queue has always used. A fork per file is what made
# this slow.
_story_meta() {
  [ -e "${1:-}" ] || return 0
  awk '
    function trim(v) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v }
    function emit(f,   fb) {
      fb = f; sub(/^.*\//, "", fb); sub(/\.md$/, "", fb)
      printf "%s\t%s\t%s\t%s\n", (id == "" ? fb : id), (dep == "" ? "None" : dep), (eff == "" ? "?" : eff), f
    }
    function reset() { id = dep = eff = ""; gid = gdep = geff = 0 }
    FNR == 1 {
      if (cur != "") emit(cur)
      for (; nxt < ARGC && ARGV[nxt] != FILENAME; nxt++) { reset(); emit(ARGV[nxt]) }
      nxt++; cur = FILENAME; reset()
    }
    !gid && /^# [^:]*:/ { t = $0; sub(/^# /, "", t); sub(/:.*/, "", t); id = trim(t); gid = 1 }
    !gdep && /^\*\*Dependencies:\*\*/ { t = $0; sub(/^\*\*Dependencies:\*\*/, "", t); dep = trim(t); gdep = 1 }
    !geff && /^\*\*Effort:\*\*/ { t = $0; sub(/^\*\*Effort:\*\*/, "", t); eff = trim(t); geff = 1 }
    BEGIN { nxt = 1 }
    END {
      if (cur != "") emit(cur)
      for (; nxt < ARGC; nxt++) { reset(); emit(ARGV[nxt]) }
    }
  ' "$@"
}

# A row counts toward the chain only if the work actually reached a branch.
_row_is_chained() {
  local outcome="$1" branch="$2"
  case "$outcome" in landed|partial) ;; *) return 1 ;; esac
  [ -n "$branch" ] && [ "$branch" != "-" ]
}

# --- commands ----------------------------------------------------------------

cmd_init_log() {
  local log="$1"
  mkdir -p "$(dirname "$log")"
  {
    echo "# story-loop log"
    echo
    echo "| Story | Outcome | PR | Branch | Base | AC | CI | Verdict | Notes |"
    echo "|---|---|---|---|---|---|---|---|---|"
  } > "$log"
}

# Story headers only. Never the body. That is the point.
cmd_index() {
  local root="$1" dir
  for dir in "$root/2_ready" "$root/1_backlog"; do
    [ -d "$dir" ] || continue
    _story_meta "$dir"/*.md
  done
}

# The second ledger. `6_completed` means merged, and it is the only durable record
# of that: the log is deliberately untracked, so it starts empty on every fresh
# checkout and knows nothing about work an earlier run -- or a human -- finished.
# Without reading this folder, a completed dependency is indistinguishable from a
# deleted one, and every story that depends on it stalls forever.
cmd_completed() {
  local root="$1"
  [ -d "$root/6_completed" ] || return 0
  _story_meta "$root/6_completed"/*.md | cut -f1
}

cmd_logged() {
  local log="$1" id="$2" row
  _rows "$log" | while IFS= read -r row; do
    [ "$(_field "$row" 1)" = "$id" ] && exit 0
  done
  # subshell exit does not propagate; re-check explicitly
  _has_line "$id" "$(_rows "$log" | cut -f1)"
}

cmd_outcome() {
  local log="$1" id="$2" row
  _rows "$log" | while IFS= read -r row; do
    if [ "$(_field "$row" 1)" = "$id" ]; then
      _field "$row" 2
      break
    fi
  done
}

# The chain head is the branch of the LAST row that actually landed work.
# A blocked row must not advance it, or the next story roots on a failure.
# A workspace log records `<repo>:<branch>`; git forbids ':' in a branch name, so
# the prefix is unambiguous. With a repo, only its rows count, prefix stripped.
_in_repo() { # _in_repo <branch-cell> <repo> ; prints the branch or fails
  if [ -z "$2" ]; then printf '%s' "$1"; return 0; fi
  case "$1" in "$2":*) printf '%s' "${1#"$2":}" ;; *) return 1 ;; esac
}

cmd_head() {
  local log="$1" base="$2" repo="${3:-}" row head="" br
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    br=$(_in_repo "$(_field "$row" 4)" "$repo") || continue
    _row_is_chained "$(_field "$row" 2)" "$br" && head="$br"
  done <<EOF
$(_rows "$log")
EOF
  printf '%s\n' "${head:-$base}"
}

# A merged story has left the chain, so depth counts only unmerged chained rows.
# A row records its merge with a Notes cell that starts with `merged`.
cmd_depth() {
  local log="$1" base="$2" repo="${3:-}" row n=0 br merged
  merged=$(_rows "$log" | awk -F'\t' '$9 ~ /^merged/ { print $1 }')
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    br=$(_in_repo "$(_field "$row" 4)" "$repo") || continue
    _has_line "$(_field "$row" 1)" "$merged" && continue
    _row_is_chained "$(_field "$row" 2)" "$br" && n=$((n + 1))
  done <<EOF
$(_rows "$log")
EOF
  printf '%s\n' "$n"
}

# Resolve dependencies for every story in one pass, reading each ledger once: the
# completed folder, the log rows and the queue index. A dependency is done if the
# log shows it landed or partial, or it sits in 6_completed (a deliberate claim
# that it merged). <mode> eligible prints the first story in the order given that
# is unlogged with every dependency done; stalled prints each unlogged story with
# the dependencies that can never be met: not done, and either logged otherwise
# or no longer queued.
_resolve() {
  local mode="$1" root="$2" log="$3" full="$4" idx="$5"
  {
    cmd_completed "$root" | awk '{ print "C\t" $0 }'
    _rows "$log" | awk '{ print "L\t" $0 }'
    printf '%s\n' "$full" | awk -F'\t' 'NF { print "Q\t" $1 }'
    printf '%s\n' "$idx" | awk 'NF { print "I\t" $0 }'
  } | awk -F'\t' -v mode="$mode" '
    function trim(v) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v }
    function done_(d) { return (out[d] == "landed" || out[d] == "partial" || (d in comp)) }
    function nodeps(x) { return (x == "None" || x == "none" || x == "NONE" || x == "-" || x == "") }
    $1 == "C" { comp[$2] = 1; next }
    $1 == "L" {
      logged[$2] = 1
      if (!($2 in out)) out[$2] = (NF >= 3 ? $3 : $2)
      next
    }
    $1 == "Q" { queued[$2] = 1; next }
    $1 == "I" { n++; line[n] = substr($0, 3); id[n] = $2; deps[n] = $3 }
    END {
      for (k = 1; k <= n; k++) {
        if (nodeps(deps[k])) {
          if (mode == "eligible" && !(id[k] in logged)) { print line[k]; exit }
          continue
        }
        if (id[k] in logged) continue
        raw = deps[k]; gsub(/,/, " ", raw)
        m = split(raw, a, /[[:space:]]+/); miss = ""; ok = 1
        for (i = 1; i <= m; i++) {
          d = trim(a[i]); if (d == "") continue
          if (done_(d)) continue
          ok = 0
          if (out[d] != "" || !(d in queued)) miss = miss (miss == "" ? "" : ",") d
        }
        if (mode == "eligible") { if (ok) { print line[k]; exit } }
        else if (miss != "") print id[k] "\t" miss
      }
    }
  '
}

cmd_eligible() {
  local root="$1" log="$2" idx full ids="" id
  if [ "${3:-}" = "--team" ]; then
    if [ -z "${4:-}" ] || [ -z "${5:-}" ]; then
      echo "eligible: --team needs <name> <adapter>" >&2
      return 2
    fi
    ids=$(cmd_teams "$5" | awk -F'\t' -v t="$4" '$1 == t && !seen++ { print $2 }')
    if [ -z "$ids" ]; then
      echo "eligible: no team '$4' in $5" >&2
      return 2
    fi
  fi
  idx=$(cmd_index "$root")
  full="$idx"
  # The team's table order replaces queue order, so a team works its own sequence.
  if [ -n "$ids" ]; then
    idx=$(for id in $(printf '%s' "$ids" | tr ',' ' '); do
      printf '%s\n' "$idx" | awk -F'\t' -v i="$id" '$1 == i'
    done)
  fi
  _resolve eligible "$root" "$log" "$full" "$idx"
  return 0
}

# The first table whose header starts with "Team": Team | Surface | Stories.
# Ids may be separated by commas, spaces or both; output joins them with commas.
cmd_teams() {
  local adapter="${1:-}"
  if [ ! -f "$adapter" ]; then
    echo "teams: no adapter at $adapter" >&2
    return 2
  fi
  awk -F'|' '
    /^[[:space:]]*\|/ {
      n = split($0, f, "|")
      c1 = f[2]; gsub(/^[ \t]+|[ \t]+$/, "", c1)
      if (!intable) { if (c1 == "Team") intable = 1; next }
      if (c1 ~ /^:?-+:?$/ || c1 == "" || n < 5) next
      raw = f[4]; gsub(/,/, " ", raw)
      m = split(raw, a, /[ \t]+/); ids = ""
      for (i = 1; i <= m; i++) if (a[i] != "") ids = ids (ids == "" ? "" : ",") a[i]
      print c1 "\t" ids
      next
    }
    intable { exit }
  ' "$adapter"
}

# A dependency is done if this loop landed it or it sits in 6_completed. Pending
# means still queued and unlogged; any other unmet dependency is permanent and is
# reported here rather than skipped, or the queue drains while stories vanish.
cmd_stalled() {
  local root="$1" log="$2"
  local idx
  idx=$(cmd_index "$root")
  _resolve stalled "$root" "$log" "$idx" "$idx"
  return 0
}

cmd_parent() {
  local log="$1" base="$2" mode="$3" deps="$4" repo="${5:-}" d last="" oc br row other=""
  case "$deps" in
    None|none|NONE|"-"|"")
      if [ "$mode" = "dag" ]; then printf '%s\n' "$base"; else cmd_head "$log" "$base" "$repo"; fi
      return 0 ;;
  esac
  # Stack on the last-landed of the declared dependencies.
  for d in $(printf '%s' "$deps" | tr ',' ' '); do
    d=$(_trim "$d")
    [ -n "$d" ] || continue
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      if [ "$(_field "$row" 1)" = "$d" ]; then
        oc=$(_field "$row" 2)
        br=$(_in_repo "$(_field "$row" 4)" "$repo") || { other=1; continue; }
        _row_is_chained "$oc" "$br" && last="$br"
      fi
    done <<EOF
$(_rows "$log")
EOF
  done
  # Only other repos' work: in this repo the story is as independent as None.
  if [ -z "$last" ] && [ -n "$other" ]; then cmd_parent "$log" "$base" "$mode" None "$repo"; return; fi
  # Linear keeps one chain: a landed dependency is already below the head.
  if [ -n "$last" ] && [ "$mode" != "dag" ]; then cmd_head "$log" "$base" "$repo"; return; fi
  printf '%s\n' "${last:-$base}"
}

# Native stacks are optional: without the gh-stack extension the chain runs on git
# branches alone, as it always could.
cmd_native_stack() {
  { [ "$#" = 5 ] || [ "$#" = 6 ]; } || { echo 'native-stack: expected forge mode teams parent base [auto|off]' >&2; return 2; }
  case "$1" in gh|az|none) ;; *) return 2 ;; esac
  case "$2" in linear|dag) ;; *) return 2 ;; esac
  case "$3" in yes|no) ;; *) return 2 ;; esac
  case "${6:-auto}" in auto|off) ;; *) return 2 ;; esac
  [ -n "$4" ] && [ -n "$5" ] || return 2
  if [ "$1" != gh ]; then echo 'skip :: forge'
  elif [ "$3" = yes ]; then echo 'skip :: teams'
  elif [ "$2" = dag ]; then echo 'skip :: dag'
  elif [ "$4" = "$5" ]; then echo 'skip :: root'
  elif [ "${6:-auto}" = off ]; then echo 'skip :: off'
  elif ! gh stack link --help >/dev/null 2>&1; then echo 'skip :: no gh stack'
  else echo link
  fi
}

# The one implementer claim the orchestrator can verify without reading a diff.
cmd_check_base() {
  local expected="$1" actual="$2"
  if [ "$expected" = "$actual" ]; then
    return 0
  fi
  echo "UNSTACKED: expected base '$expected', implementer returned '$actual'" >&2
  return 1
}

cmd_append() {
  local log="$1"; shift
  if [ "$#" -ne "$LOG_COLS" ]; then
    echo "append needs $LOG_COLS fields, got $#" >&2
    return 2
  fi
  [ -f "$log" ] || cmd_init_log "$log"
  local out="|" f nl='
'
  for f in "$@"; do
    f=${f//|//}; f=${f//$nl/ }
    [ -n "$f" ] || f="-"
    out="$out $f |"
  done
  printf '%s\n' "$out" >> "$log"
  _trim_log "$log" 50
}

# Only `stop` rows older than the newest <keep> rows go. Every story row stays,
# merged ones included: `eligible` excludes a story by its row alone.
_trim_log() {
  local log="$1" keep="$2" hdr=4 tmp
  [ "$(wc -l < "$log")" -gt $((hdr + keep)) ] || return 0
  tmp="$log.tmp.$$"
  awk -v hdr="$hdr" -v keep="$keep" '
    { line[NR] = $0 }
    NR > hdr { n = split($0, f, "|"); oc = f[3]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", oc); stop[NR] = (oc == "stop") }
    END { for (i = 1; i <= NR; i++) if (i <= hdr || i > NR - keep || !stop[i]) print line[i] }
  ' "$log" > "$tmp" && mv "$tmp" "$log"
}

# --- adapter -----------------------------------------------------------------

ADAPTER_FIELDS='Queue root|Log path|Base branch|Remote|Stack mode|Stack depth cap|Forge|CI system|CI wait|Verifier|Verdict dir|Verdict archive|Review rubric|Unverifiable gates|Escalation threshold|Merge policy|Human-only categories|Remediate should-fix|Review list|Native stacks|Setup command|Build command|Test command|E2E command|E2E in PR CI|Narrowed e2e|Stack policy|Stack up command|Stack down command|Test DB command|Worktree env files|Scratch root|Model tiers|Implementer agent|Closeout by|Full runs at'

_adapter_default() {
  case "$1" in
    'Log path') echo 'tasks/loop-log.md' ;;
    'Remote') echo 'origin' ;;
    'Stack mode') echo 'linear' ;;
    'Stack depth cap') echo '10' ;;
    'CI wait') echo '4' ;;
    'Verdict dir') echo '~/.local/state/pr-verdicts/<repo>' ;;
    'Verdict archive') echo 'tasks/archive/reviews/' ;;
    'Escalation threshold') echo '8' ;;
    'Merge policy') echo 'never' ;;
    'Human-only categories') echo 'auth, payments, migrations' ;;
    'Remediate should-fix') echo 'off' ;;
    'Native stacks') echo 'auto' ;;
    'E2E in PR CI') echo 'no' ;;
    'Stack policy') echo 'ask' ;;
    'Scratch root') echo '${TMPDIR:-/tmp}/story-loop/<repo>' ;;
    'Model tiers') echo 'implementer=standard verifier=standard filer=light' ;;
    'Implementer agent') echo 'story-implementer' ;;
    'Closeout by') echo 'orchestrator' ;;
    'Full runs at') echo 'ci' ;;
    'Stack lock format') echo 'loop' ;;
    'Queue root'|'Base branch') echo '' ;;
    *) echo 'none' ;;
  esac
}

_adapter_alias() {
  case "$1" in
    'Stack policy') echo 'Local stack policy' ;;
    'Stack down command') echo 'Local stack teardown' ;;
    'Test DB command') echo 'Isolated test DB' ;;
    'Human-only categories') echo 'Merge exclusions' ;;
  esac
}

# First matching row of any pipe table, key in column 1, case-insensitive.
_table_value() {
  [ -f "$1" ] || return 0
  awk -F'|' -v want="$2" '
    /^[[:space:]]*\|/ {
      k = $2; gsub(/^[ \t]+|[ \t]+$/, "", k)
      if (tolower(k) == tolower(want)) {
        v = $3; gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/`/, "", v); print v; exit
      }
    }' "$1"
}

cmd_adapter_raw() {
  local file="$1" field="$2" v alias
  v=$(_table_value "$file" "$field")
  alias=$(_adapter_alias "$field")
  [ -n "$v" ] || [ -z "$alias" ] || v=$(_table_value "$file" "$alias")
  printf '%s\n' "$v"
}

cmd_adapter() {
  local v
  v=$(cmd_adapter_raw "$1" "$2")
  [ -n "$v" ] || v=$(_adapter_default "$2")
  printf '%s\n' "$v"
}

# Relative paths in an adapter are relative to the repo that holds it, never the
# caller's cwd, so a member repo can name a workspace queue as ../workspace/...
cmd_adapter_path() {
  local file="$1" field="$2" v dir root
  v=$(cmd_adapter "$file" "$field")
  case "$v" in ''|none) printf '%s\n' "$v"; return 0 ;; '~/'*) v="$HOME/${v#\~/}" ;;
    '${TMPDIR:-/tmp}'*) v="${TMPDIR:-/tmp}${v#\$\{TMPDIR:-/tmp\}}" ;; esac
  case "$v" in /*) ;; *)
    dir=$(cd "$(dirname "$file")" && pwd -P) || return 1
    root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || root="$dir"
    v="$root/$v" ;;
  esac
  printf '%s\n' "$v"
}

_one_of() { case "|$2|" in *"|$1|"*) return 0 ;; esac; return 1; }

cmd_adapter_check() {
  local file="$1" f v err=0
  [ -f "$file" ] || { echo "adapter not found: $file" >&2; return 1; }
  while IFS= read -r f; do
    printf '%s\t%s\n' "$f" "$(cmd_adapter "$file" "$f")"
  done <<EOF
$(printf '%s' "$ADAPTER_FIELDS" | tr '|' '\n')
EOF
  _bad() { echo "adapter: $1" >&2; err=1; }
  _enum() { # _enum <field> <a|b>
    v=$(cmd_adapter "$file" "$1"); _one_of "$v" "$2" || _bad "$1 '$v' is not $2"
  }
  for f in 'Queue root' 'Base branch'; do
    [ -n "$(cmd_adapter "$file" "$f")" ] || _bad "$f is required"
  done
  _enum 'Stack mode' 'linear|dag'
  _enum 'Forge' 'gh|az|none'
  _enum 'CI system' 'github-actions|azure-pipelines|none'
  _enum 'Merge policy' 'never|clean-verdict'
  _enum 'Stack policy' 'ask|own|none'
  _enum 'E2E in PR CI' 'yes|no'
  _enum 'Remediate should-fix' 'off|on'
  _enum 'Native stacks' 'auto|off'
  _enum 'Closeout by' 'orchestrator|implementer'
  for f in 'Escalation threshold' 'CI wait'; do
    v=$(cmd_adapter "$file" "$f")
    case "$v" in ''|*[!0-9]*) _bad "$f '$v' is not a non-negative integer" ;; esac
  done
  v=$(cmd_adapter "$file" 'Stack depth cap')
  case "$v" in none) ;; ''|*[!0-9]*) _bad "Stack depth cap '$v' is not an integer or none" ;; esac
  v=$(cmd_adapter "$file" 'Stack down command')
  case " $v " in *' -v '*|*' --volumes '*|*'--no-backup'*)
    _bad "Stack down command '$v' deletes shared volumes" ;; esac
  v=$(cmd_adapter "$file" 'Model tiers')
  for f in implementer verifier filer; do
    case " $v " in *" $f="?*) ;; *) _bad "Model tiers is missing $f=<tier>" ;; esac
  done
  if [ "$(cmd_adapter "$file" 'Merge policy')" = clean-verdict ]; then
    [ "$(cmd_adapter "$file" 'Forge')" != none ] || _bad "Merge policy clean-verdict needs a forge"
    [ "$(cmd_adapter "$file" 'Verifier')" != none ] || _bad "Merge policy clean-verdict needs a verifier"
  fi
  return $err
}

# Longest-prefix row of the table headed `| Path |`; blank cell or no row falls
# back to the `<column> command` field.
cmd_command() {
  local file="$1" col="$2" path="${3:-.}" v
  v=$(awk -F'|' -v col="$col" -v path="$path" '
    function trim(x) { gsub(/^[ \t`]+|[ \t`]+$/, "", x); return x }
    /^[[:space:]]*\|/ {
      if (tolower(trim($2)) == "path") {
        ci = 0; for (i = 3; i < NF; i++) if (tolower(trim($i)) == tolower(col)) ci = i
        intable = 1; next
      }
      if (!intable || trim($2) ~ /^-+$/) next
      p = trim($2); sub(/\/$/, "", p)
      if (ci && (p == "." || path == p || index(path, p "/") == 1) && length(p) >= best) {
        c = trim($ci); if (c != "") { best = length(p); out = c }
      }
      next
    }
    { intable = 0 }
    END { print out }' "$file")
  [ -n "$v" ] || v=$(cmd_adapter "$file" "$col command")
  printf '%s\n' "$v"
}

cmd_repo_path() {
  local v
  v=$(_table_value "$1" "$2")
  [ -n "$v" ] || { echo "repo '$2' not in $1" >&2; return 1; }
  printf '%s\n' "$v"
}

_header() { # _header <story> <name>
  local v
  v=$(sed -n "s/^\*\*$2:\*\*[[:space:]]*//p" "$1" | head -1)
  v=$(_trim "${v:-}")
  printf '%s\n' "${v:-none}"
}

cmd_categories() { _header "$1" Categories; }
cmd_paths()      { _header "$1" Paths; }
cmd_repo()       { _header "$1" Repo; }

_lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
# Fail closed: any case, any of `/ , ;` or whitespace, singular or plural.
_cat_words() { _lc "$1" | tr '/,;' '   ' | tr -s '[:space:]' '\n' | sed -e '/^$/d' -e 's/s$//'; }

# Clean is verdict MERGE, BLOCKING 0, ESCALATION 0, CI green, unmet criteria filed
# forward, and no human-only category. Anything else waits for a person.
cmd_merge_gate() {
  if [ "$#" -ne 9 ]; then echo "merge-gate needs 9 arguments, got $#" >&2; return 2; fi
  local policy="$1" verdict="$2" blocking="$3" esc="$4" ci="$5" ac="$6" fwd="$7" cats="$8" human="$9" c h
  ac=$(printf '%s' "$ac" | tr -d '[:space:]')
  hold() { printf 'hold :: %s\n' "$1"; return 1; }
  [ "$policy" = clean-verdict ] || { hold "merge policy $policy"; return 1; }
  [ "$verdict" = MERGE ]        || { hold "verdict $verdict"; return 1; }
  [ "$blocking" = 0 ]           || { hold "blocking $blocking"; return 1; }
  [ "$esc" = 0 ]                || { hold "escalation $esc"; return 1; }
  [ "$ci" = green ]             || { hold "ci $ci"; return 1; }
  local n_tick="${ac%%/*}" n_all="${ac##*/}"
  case "$ac" in
    */*/*) hold "ac '$ac' unreadable"; return 1 ;;
    [0-9]*/[0-9]*) ;;
    *) hold "ac '$ac' unreadable"; return 1 ;;
  esac
  case "$n_tick$n_all" in *[!0-9]*) hold "ac '$ac' unreadable"; return 1 ;; esac
  if [ "$n_all" -eq 0 ] || [ "$n_tick" -gt "$n_all" ]; then hold "ac '$ac' unreadable"; return 1; fi
  if [ "$n_tick" -ne "$n_all" ] && [ "$fwd" != yes ]; then
    hold "unmet criteria $ac not filed forward"; return 1
  fi
  for c in $(_cat_words "$cats"); do
    [ "$c" = none ] && continue
    for h in $(_cat_words "$human"); do
      [ "$c" = "$h" ] && { hold "human-only category $c"; return 1; }
    done
  done
  echo merge
}

# --- dispatch ----------------------------------------------------------------

case "${1:-help}" in
  init-log)   shift; cmd_init_log "$@" ;;
  index)      shift; cmd_index "$@" ;;
  completed)  shift; cmd_completed "$@" ;;
  logged)     shift; cmd_logged "$@" ;;
  outcome)    shift; cmd_outcome "$@" ;;
  head)       shift; cmd_head "$@" ;;
  depth)      shift; cmd_depth "$@" ;;
  eligible)   shift; cmd_eligible "$@" ;;
  stalled)    shift; cmd_stalled "$@" ;;
  teams)      shift; cmd_teams "$@" ;;
  parent)     shift; cmd_parent "$@" ;;
  check-base) shift; cmd_check_base "$@" ;;
  native-stack) shift; cmd_native_stack "$@" ;;
  append)     shift; cmd_append "$@" ;;
  categories) shift; cmd_categories "$@" ;;
  adapter)    shift; cmd_adapter "$@" ;;
  adapter-check) shift; cmd_adapter_check "$@" ;;
  adapter-raw) shift; cmd_adapter_raw "$@" ;;
  adapter-path) shift; cmd_adapter_path "$@" ;;
  command)    shift; cmd_command "$@" ;;
  paths)      shift; cmd_paths "$@" ;;
  repo)       shift; cmd_repo "$@" ;;
  repo-path)  shift; cmd_repo_path "$@" ;;
  merge-gate) shift; cmd_merge_gate "$@" ;;
  help|--help|-h) usage ;;
  *) echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
