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
# dependency silently stops matching itself.
_story_id() {
  local f="$1" id
  id=$(sed -n 's/^# \([^:]*\):.*/\1/p' "$f" | head -1)
  id=$(_trim "${id:-}")
  [ -n "$id" ] || id=$(basename "$f" .md)
  printf '%s' "$id"
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
  local root="$1" dir f id deps effort
  for dir in "$root/2_ready" "$root/1_backlog"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.md; do
      [ -e "$f" ] || continue
      id=$(_story_id "$f")
      deps=$(sed -n 's/^\*\*Dependencies:\*\*[[:space:]]*//p' "$f" | head -1)
      deps=$(_trim "${deps:-None}")
      [ -z "$deps" ] && deps="None"
      effort=$(sed -n 's/^\*\*Effort:\*\*[[:space:]]*//p' "$f" | head -1)
      effort=$(_trim "${effort:-?}")
      [ -z "$effort" ] && effort="?"
      printf '%s\t%s\t%s\t%s\n' "$id" "$deps" "$effort" "$f"
    done
  done
}

# The second ledger. `6_completed` means merged, and it is the only durable record
# of that: the log is deliberately untracked, so it starts empty on every fresh
# checkout and knows nothing about work an earlier run -- or a human -- finished.
# Without reading this folder, a completed dependency is indistinguishable from a
# deleted one, and every story that depends on it stalls forever.
cmd_completed() {
  local root="$1" f
  [ -d "$root/6_completed" ] || return 0
  for f in "$root/6_completed"/*.md; do
    [ -e "$f" ] || continue
    printf '%s\n' "$(_story_id "$f")"
  done
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

# A dependency is done if this loop landed it, or if it sits in 6_completed. Those
# are the two ledgers and they are checked in that order. A row logged blocked
# makes the dependent ineligible; it never silently roots at base. Sitting in
# 6_completed outranks that, because moving a file there is a deliberate claim
# that the work merged, and merged work is already in the base branch.
_dep_done() {
  local root="$1" log="$2" d="$3" oc
  oc=$(cmd_outcome "$log" "$d")
  case "$oc" in landed|partial) return 0 ;; esac
  _has_line "$d" "$(cmd_completed "$root")"
}

_deps_satisfied() {
  local root="$1" log="$2" deps="$3" d
  case "$deps" in None|none|NONE|"-"|"") return 0 ;; esac
  for d in $(printf '%s' "$deps" | tr ',' ' '); do
    d=$(_trim "$d")
    [ -n "$d" ] || continue
    _dep_done "$root" "$log" "$d" || return 1
  done
  return 0
}

cmd_eligible() {
  local root="$1" log="$2" idx logged ids="" id line deps
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
  logged=$(_rows "$log" | cut -f1)
  # The team's table order replaces queue order, so a team works its own sequence.
  if [ -n "$ids" ]; then
    idx=$(for id in $(printf '%s' "$ids" | tr ',' ' '); do
      printf '%s\n' "$idx" | awk -F'\t' -v i="$id" '$1 == i'
    done)
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id=$(_field "$line" 1)
    deps=$(_field "$line" 2)
    if _has_line "$id" "$logged"; then continue; fi
    if _deps_satisfied "$root" "$log" "$deps"; then
      printf '%s\n' "$line"
      return 0
    fi
  done <<EOF
$idx
EOF
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

# A dependency is "pending" if it is still sitting in the queue and could land
# later. Anything else unsatisfied is permanent: it was attempted and blocked, or
# it does not exist at all. Permanent cases must be logged, not silently skipped,
# or the queue drains while stories vanish.
_dep_is_pending() {
  local root="$1" log="$2" d="$3" oc
  _dep_done "$root" "$log" "$d" && return 1      # already done: not pending
  oc=$(cmd_outcome "$log" "$d")
  [ -n "$oc" ] && return 1                       # logged and not landed: permanent
  _has_line "$d" "$(cmd_index "$root" | cut -f1)"  # still queued: pending
}

cmd_stalled() {
  local root="$1" log="$2" line id deps d missing
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id=$(_field "$line" 1)
    deps=$(_field "$line" 2)
    case "$deps" in None|none|NONE|"-"|"") continue ;; esac
    if _has_line "$id" "$(_rows "$log" | cut -f1)"; then continue; fi
    _deps_satisfied "$root" "$log" "$deps" && continue
    missing=""
    for d in $(printf '%s' "$deps" | tr ',' ' '); do
      d=$(_trim "$d")
      [ -n "$d" ] || continue
      _dep_done "$root" "$log" "$d" && continue
      if ! _dep_is_pending "$root" "$log" "$d"; then
        missing="${missing:+$missing,}$d"
      fi
    done
    [ -n "$missing" ] && printf '%s\t%s\n' "$id" "$missing"
  done <<EOF
$(cmd_index "$root")
EOF
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
