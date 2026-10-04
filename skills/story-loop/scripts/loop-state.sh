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
  head <log> <base>                       Print the chain head branch
  eligible <queue-root> <log> [--team <name> <adapter>]
                                          Print the next eligible story, or nothing;
                                          --team limits it to that team, in table order
  teams <adapter>                         List the adapter's teams: team<TAB>id,id,...
  stalled <queue-root> <log>              List stories whose dependencies can never be met
  parent <log> <base> <mode> <deps>       Print the parent branch for a story
  check-base <expected> <actual>          Exit 0 if they match, 1 and a message if not
  depth <log> <base>                      Print the current chain depth
  append <log> <9 fields...>              Append one row

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
cmd_head() {
  local log="$1" base="$2" row head=""
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    if _row_is_chained "$(_field "$row" 2)" "$(_field "$row" 4)"; then
      head=$(_field "$row" 4)
    fi
  done <<EOF
$(_rows "$log")
EOF
  printf '%s\n' "${head:-$base}"
}

cmd_depth() {
  local log="$1" base="$2" row n=0
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    _row_is_chained "$(_field "$row" 2)" "$(_field "$row" 4)" && n=$((n + 1))
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
  local log="$1" base="$2" mode="$3" deps="$4" d last="" oc br row
  case "$deps" in
    None|none|NONE|"-"|"")
      if [ "$mode" = "dag" ]; then printf '%s\n' "$base"; else cmd_head "$log" "$base"; fi
      return 0 ;;
  esac
  # Stack on the last-landed of the declared dependencies.
  for d in $(printf '%s' "$deps" | tr ',' ' '); do
    d=$(_trim "$d")
    [ -n "$d" ] || continue
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      if [ "$(_field "$row" 1)" = "$d" ]; then
        oc=$(_field "$row" 2); br=$(_field "$row" 4)
        _row_is_chained "$oc" "$br" && last="$br"
      fi
    done <<EOF
$(_rows "$log")
EOF
  done
  printf '%s\n' "${last:-$base}"
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
  local out="|" f
  for f in "$@"; do
    [ -n "$f" ] || f="-"
    out="$out $f |"
  done
  printf '%s\n' "$out" >> "$log"
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
  append)     shift; cmd_append "$@" ;;
  help|--help|-h) usage ;;
  *) echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
