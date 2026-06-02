#!/usr/bin/env bash
set -euo pipefail

SKILLS_SRC="$(dirname "$0")/skills"
SKILLS_DEST="$HOME/.config/opencode/skills"
COMMANDS_SRC="$(dirname "$0")/commands"
COMMANDS_DEST="$HOME/.config/opencode/commands"

usage() {
  cat <<EOF
Usage: ./setup.sh [command]

Commands:
  setup            Deploy both skills and commands (default)
  deploy-skills    Sync skills to global opencode config
  deploy-commands  Sync slash commands to global opencode config
  diff-skills      Show drift between repo and deployed skills
  diff-commands    Show drift between repo and deployed commands
  help             Show this help message
EOF
}

deploy_skills() {
  echo "Deploying skills → $SKILLS_DEST"
  mkdir -p "$SKILLS_DEST"
  rsync -av --delete --exclude='.DS_Store' "$SKILLS_SRC/" "$SKILLS_DEST/"
  count=$(find "$SKILLS_SRC" -name 'SKILL.md' | wc -l | tr -d ' ')
  echo "Done. $count skill(s) deployed."
}

deploy_commands() {
  echo "Deploying commands → $COMMANDS_DEST"
  mkdir -p "$COMMANDS_DEST"
  rsync -av --delete --exclude='.DS_Store' "$COMMANDS_SRC/" "$COMMANDS_DEST/"
  count=$(find "$COMMANDS_SRC" -name '*.md' | wc -l | tr -d ' ')
  echo "Done. $count command(s) deployed."
}

diff_skills() {
  diff -rq "$SKILLS_SRC" "$SKILLS_DEST" 2>/dev/null || true
}

diff_commands() {
  diff -rq "$COMMANDS_SRC" "$COMMANDS_DEST" 2>/dev/null || true
}

case "${1:-setup}" in
  setup)           deploy_skills && deploy_commands && echo "Setup complete." ;;
  deploy-skills)   deploy_skills ;;
  deploy-commands) deploy_commands ;;
  diff-skills)     diff_skills ;;
  diff-commands)   diff_commands ;;
  help|--help|-h)  usage ;;
  *)               echo "Unknown command: $1"; usage; exit 1 ;;
esac
