#!/usr/bin/env bash
#
# cleanup.sh -- remove what setup.sh deployed.
#
# Thin wrapper around `setup.sh clean` so there is a single source of truth for
# the removal logic (add a tool once, in setup.sh, and both scripts learn it).
#
# Removal is name-based and surgical: for every skill/command this repo owns,
# the matching file at the destination is deleted -- and nothing else. For
# ~/.claude/CLAUDE.md, only the delimited skills rules block is
# stripped. Your own skills, commands, and notes are always left untouched.
#
# Usage mirrors setup.sh:
#   ./cleanup.sh                    scan for deployed content, prompt per tool
#   ./cleanup.sh -y                 remove from every tool where it's found
#   ./cleanup.sh opencode|codex|claude
#   ./cleanup.sh claude-skills|claude-commands|claude-rules
#   ./cleanup.sh help
set -euo pipefail

exec "$(dirname "$0")/setup.sh" clean "$@"
