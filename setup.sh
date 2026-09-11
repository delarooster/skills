#!/usr/bin/env bash
set -euo pipefail

SKILLS_SRC="$(dirname "$0")/skills"
COMMANDS_SRC="$(dirname "$0")/commands"
CLAUDE_AGENTS_SRC="$(dirname "$0")/agents"
INSTRUCTIONS_SRC="$(dirname "$0")/INSTRUCTIONS.md"

# Deployment destinations
OPENCODE_DIR="$HOME/.config/opencode"
OPENCODE_SKILLS_DEST="$OPENCODE_DIR/skills"
OPENCODE_COMMANDS_DEST="$OPENCODE_DIR/commands"
AGENTS_SKILLS_DEST="$HOME/.agents/skills"   # shared: OpenCode (external) + Codex

CODEX_DIR="$HOME/.codex"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DEST="$CLAUDE_DIR/skills"
CLAUDE_COMMANDS_DEST="$CLAUDE_DIR/commands"
CLAUDE_AGENTS_DEST="$CLAUDE_DIR/agents"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
RETIRED_CLAUDE_AGENTS="verdict-scorer.md:7125a86a199dde0ebc60ec9427925b8acf68860c3e0397f57d2e5816a4a5c11c"

# Where each tool reads its global, always-on instructions. Every one of these
# is a markdown file we merge into, never overwrite -- see RULES_BLOCK_START.
#   Claude Code  ~/.claude/CLAUDE.md
#   Codex        $CODEX_HOME/AGENTS.md          (CODEX_HOME defaults to ~/.codex)
#   OpenCode     <global config dir>/AGENTS.md  (`opencode debug paths` -> config)
CODEX_RULES_MD="$CODEX_DIR/AGENTS.md"
OPENCODE_RULES_MD="$OPENCODE_DIR/AGENTS.md"

# Delimiters wrapping the workspace rules block inside a tool's instructions
# file. Content between these markers is fully owned by this script (replaced
# on every deploy); everything else in that file is left untouched.
RULES_BLOCK_START="<!-- skills:rules:start (auto-managed by setup.sh -- do not edit inside this block) -->"
RULES_BLOCK_END="<!-- skills:rules:end -->"

usage() {
  cat <<EOF
Usage: ./setup.sh [command]

With NO command, ./setup.sh scans your machine for installed AI coding tools
(OpenCode, Codex, Claude Code) and deploys this repo's skills, commands, agents,
and rules to each one it finds -- prompting per tool. This is the easy path:
just run ./setup.sh and answer the prompts. Add -y to accept every detected
tool without prompting.

Requires bash + rsync. On macOS and Linux these ship by default. On Windows,
run this from Git Bash or WSL (native cmd/PowerShell are not supported); if
rsync isn't installed the script falls back to a plain copy. Prefer Git Bash
unless your AI tool is also installed inside WSL -- under WSL, $HOME is the
Linux home (/home/you), not C:\Users\you, so a Windows-native tool install
won't see anything deployed there.

Common:
  (no command)            Auto-detect installed tools and prompt per tool
  auto [-y]               Same as no command; -y accepts all detected tools
  opencode                Deploy skills + commands + rules → OpenCode (~/.config/opencode)
  codex                   Deploy skills + rules → Codex (~/.agents, ~/.codex)
  claude                  Deploy skills, commands, rules → Claude Code (~/.claude)
  setup                   Force-deploy to ALL targets whether detected or not

Cleanup (remove what was deployed -- see also ./cleanup.sh):
  clean [-y]              Scan for deployed content and remove it, prompting
                          per tool (defaults to No); -y removes from all found
  clean opencode          Remove this repo's skills + commands + rules from OpenCode
  clean codex             Remove this repo's skills + rules from Codex
  clean claude            Remove this repo's skills, commands, and rules block
  clean claude-skills     Remove only this repo's skills from ~/.claude/skills
  clean claude-commands   Remove only this repo's commands from ~/.claude/commands
  clean claude-agents     Remove only this repo's agents from ~/.claude/agents
  clean claude-rules      Strip the rules block from ~/.claude/CLAUDE.md
  clean codex-rules       Strip the rules block from ~/.codex/AGENTS.md
  clean opencode-rules    Strip the rules block from ~/.config/opencode/AGENTS.md
                          Removal is name-based: only files this repo owns are
                          deleted; your own skills/commands/notes are kept.

Granular (explicit source-of-truth control / upgrades):
  deploy-skills           Sync skills → opencode config (~/.config/opencode/skills)
  deploy-commands         Sync slash commands → opencode config
  deploy-codex-skills     Sync skills → ~/.agents/skills (Codex + OpenCode external)
  deploy-all-skills       Sync skills to both opencode and codex/agents destinations
  deploy-claude           Sync skills, commands, agents, and rules → ~/.claude (additive)
  deploy-claude-skills    Sync skills → ~/.claude/skills (additive)
  deploy-claude-commands  Sync slash commands → ~/.claude/commands (additive)
  deploy-claude-agents    Sync Claude agents → ~/.claude/agents (additive)
  deploy-claude-rules     Merge INSTRUCTIONS.md into ~/.claude/CLAUDE.md (additive)
  deploy-codex-rules      Merge INSTRUCTIONS.md into ~/.codex/AGENTS.md (additive)
  deploy-opencode-rules   Merge INSTRUCTIONS.md into ~/.config/opencode/AGENTS.md
                          (additive)
  diff-skills             Show drift between repo and opencode deployed skills
  diff-codex-skills       Show drift between repo and codex/agents deployed skills
  diff-commands           Show drift between repo and deployed commands
  diff-claude-skills      Show drift between repo and claude deployed skills
  diff-claude-commands    Show drift between repo and claude deployed commands
  diff-claude-agents      Show drift between repo and claude deployed agents
  diff-claude-rules       Show drift between INSTRUCTIONS.md and the CLAUDE.md rules block
  diff-codex-rules        Show drift between INSTRUCTIONS.md and the Codex rules block
  diff-opencode-rules     Show drift between INSTRUCTIONS.md and the OpenCode rules block
  help                    Show this help message

"Additive" targets (claude-*) never delete files they didn't create. They add or
update current content and remove only unchanged, explicitly retired content from
this repo, so anything else you already have in ~/.claude is left alone.

Rules deployment is additive for every tool. INSTRUCTIONS.md is merged into the
instructions file each tool already reads -- ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md,
~/.config/opencode/AGENTS.md -- inside a delimited, auto-managed block. Whatever
else those files contain is yours and is never touched.
EOF
}

_has_rsync() { command -v rsync >/dev/null 2>&1; }

# Mirror src into dest, deleting anything in dest that isn't in src.
_sync_mirror() {
  local src="$1" dest="$2"
  mkdir -p "$dest"
  if _has_rsync; then
    rsync -av --delete --exclude='.DS_Store' "$src/" "$dest/"
  else
    echo "  (rsync not found -- falling back to cp; install rsync, e.g. via WSL or Git Bash's pacman, for cleaner syncs)"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
    find "$dest" -name '.DS_Store' -delete
  fi
}

# Copy/update src into dest without deleting anything already in dest.
_sync_additive() {
  local src="$1" dest="$2"
  mkdir -p "$dest"
  if _has_rsync; then
    rsync -av --exclude='.DS_Store' "$src/" "$dest/"
  else
    echo "  (rsync not found -- falling back to cp; install rsync, e.g. via WSL or Git Bash's pacman, for cleaner syncs)"
    cp -R "$src/." "$dest/"
    find "$dest" -name '.DS_Store' -delete
  fi
}

_sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  else
    return 1
  fi
}

_remove_retired_agents() {
  local dest="$1" record name expected actual removed=0
  [[ -d "$dest" ]] || return 0
  for record in $RETIRED_CLAUDE_AGENTS; do
    name="${record%%:*}"
    expected="${record#*:}"
    [[ -f "$dest/$name" && ! -L "$dest/$name" ]] || continue
    if ! actual="$(_sha256_file "$dest/$name")"; then
      echo "  Kept retired agent $name because no SHA-256 tool is available."
    elif [[ "$actual" == "$expected" ]]; then
      rm -f "${dest:?}/$name"
      removed=$((removed + 1))
    else
      echo "  Kept modified retired agent $name."
    fi
  done
  [[ "$removed" == 0 ]] || echo "  Removed $removed retired agent(s)."
}

_deploy_to() {
  local dest="$1"
  echo "Deploying skills → $dest"
  _sync_mirror "$SKILLS_SRC" "$dest"
  count=$(find "$SKILLS_SRC" -name 'SKILL.md' | wc -l | tr -d ' ')
  echo "Done. $count skill(s) deployed."
}

deploy_skills() {
  _deploy_to "$OPENCODE_SKILLS_DEST"
}

deploy_codex_skills() {
  _deploy_to "$AGENTS_SKILLS_DEST"
}

deploy_all_skills() {
  _deploy_to "$OPENCODE_SKILLS_DEST"
  _deploy_to "$AGENTS_SKILLS_DEST"
}

deploy_commands() {
  echo "Deploying commands → $OPENCODE_COMMANDS_DEST"
  _sync_mirror "$COMMANDS_SRC" "$OPENCODE_COMMANDS_DEST"
  count=$(find "$COMMANDS_SRC" -name '*.md' | wc -l | tr -d ' ')
  echo "Done. $count command(s) deployed."
}

deploy_claude_skills() {
  echo "Deploying skills → $CLAUDE_SKILLS_DEST (additive)"
  _sync_additive "$SKILLS_SRC" "$CLAUDE_SKILLS_DEST"
  count=$(find "$SKILLS_SRC" -name 'SKILL.md' | wc -l | tr -d ' ')
  echo "Done. $count skill(s) synced. Anything else already in $CLAUDE_SKILLS_DEST is left untouched."
}

deploy_claude_commands() {
  echo "Deploying commands → $CLAUDE_COMMANDS_DEST (additive)"
  _sync_additive "$COMMANDS_SRC" "$CLAUDE_COMMANDS_DEST"
  count=$(find "$COMMANDS_SRC" -name '*.md' | wc -l | tr -d ' ')
  echo "Done. $count command(s) synced. Anything else already in $CLAUDE_COMMANDS_DEST is left untouched."
}

deploy_claude_agents() {
  echo "Deploying agents → $CLAUDE_AGENTS_DEST (additive)"
  _remove_retired_agents "$CLAUDE_AGENTS_DEST"
  _sync_additive "$CLAUDE_AGENTS_SRC" "$CLAUDE_AGENTS_DEST"
  count=$(find "$CLAUDE_AGENTS_SRC" -name '*.md' | wc -l | tr -d ' ')
  echo "Done. $count agent(s) synced. Anything else already in $CLAUDE_AGENTS_DEST is left untouched."
}

# Merge INSTRUCTIONS.md into a tool's instructions file inside a delimited
# block. Re-running replaces only that block, so edits elsewhere in the file
# (the user's own notes/preferences) are preserved.
_deploy_rules_to() {
  local target="$1"
  echo "Merging workspace rules → $target (additive)"
  mkdir -p "$(dirname "$target")"
  local block tmp
  block="$(mktemp)"
  tmp="$(mktemp)"
  {
    printf '%s\n' "$RULES_BLOCK_START"
    cat "$INSTRUCTIONS_SRC"
    printf '%s\n' "$RULES_BLOCK_END"
  } > "$block"

  if [[ -f "$target" ]] && grep -qF "$RULES_BLOCK_START" "$target"; then
    awk -v start="$RULES_BLOCK_START" -v end="$RULES_BLOCK_END" -v blockfile="$block" '
      $0 == start { while ((getline line < blockfile) > 0) print line; close(blockfile); skipping=1; next }
      $0 == end { skipping=0; next }
      skipping { next }
      { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
    echo "Done. Existing rules block updated; rest of $target left untouched."
  elif [[ -f "$target" ]]; then
    cp "$target" "$tmp"
    printf '\n' >> "$tmp"
    cat "$block" >> "$tmp"
    mv "$tmp" "$target"
    echo "Done. Rules block appended; existing content in $target left untouched."
  else
    cp "$block" "$target"
    echo "Done. Created $target with the rules block."
  fi
  rm -f "$block"
}

deploy_claude_rules()   { _deploy_rules_to "$CLAUDE_MD"; }
deploy_codex_rules()    { _deploy_rules_to "$CODEX_RULES_MD"; }
deploy_opencode_rules() { _deploy_rules_to "$OPENCODE_RULES_MD"; }

deploy_claude() {
  deploy_claude_skills
  deploy_claude_commands
  deploy_claude_agents
  deploy_claude_rules
}

diff_skills() {
  echo "Diff: repo vs opencode ($OPENCODE_SKILLS_DEST)"
  diff -rq "$SKILLS_SRC" "$OPENCODE_SKILLS_DEST" 2>/dev/null || true
}

diff_codex_skills() {
  echo "Diff: repo vs codex/agents ($AGENTS_SKILLS_DEST)"
  diff -rq "$SKILLS_SRC" "$AGENTS_SKILLS_DEST" 2>/dev/null || true
}

diff_commands() {
  diff -rq "$COMMANDS_SRC" "$OPENCODE_COMMANDS_DEST" 2>/dev/null || true
}

diff_claude_skills() {
  echo "Diff: repo vs claude ($CLAUDE_SKILLS_DEST) -- extra files in dest are expected (additive)"
  diff -rq "$SKILLS_SRC" "$CLAUDE_SKILLS_DEST" 2>/dev/null | grep -vF "Only in $CLAUDE_SKILLS_DEST" || true
}

diff_claude_commands() {
  echo "Diff: repo vs claude ($CLAUDE_COMMANDS_DEST) -- extra files in dest are expected (additive)"
  diff -rq "$COMMANDS_SRC" "$CLAUDE_COMMANDS_DEST" 2>/dev/null | grep -vF "Only in $CLAUDE_COMMANDS_DEST" || true
}

diff_claude_agents() {
  echo "Diff: repo vs claude ($CLAUDE_AGENTS_DEST) -- extra files in dest are expected (additive)"
  diff -rq "$CLAUDE_AGENTS_SRC" "$CLAUDE_AGENTS_DEST" 2>/dev/null | grep -vF "Only in $CLAUDE_AGENTS_DEST" || true
}

# $1 = instructions file to inspect, $2 = the deploy command that fills it.
_diff_rules_at() {
  local target="$1" cmd="$2"
  echo "Diff: repo INSTRUCTIONS.md vs $target rules block"
  if [[ ! -f "$target" ]] || ! grep -qF "$RULES_BLOCK_START" "$target"; then
    echo "No skills rules block found in $target. Run: ./setup.sh $cmd"
    return
  fi
  local current
  current="$(mktemp)"
  awk -v start="$RULES_BLOCK_START" -v end="$RULES_BLOCK_END" '
    $0 == start { inblock=1; next }
    $0 == end { inblock=0; next }
    inblock { print }
  ' "$target" > "$current"
  diff "$INSTRUCTIONS_SRC" "$current" || true
  rm -f "$current"
}

diff_claude_rules()   { _diff_rules_at "$CLAUDE_MD" "deploy-claude-rules"; }
diff_codex_rules()    { _diff_rules_at "$CODEX_RULES_MD" "deploy-codex-rules"; }
diff_opencode_rules() { _diff_rules_at "$OPENCODE_RULES_MD" "deploy-opencode-rules"; }

# --- Cleanup (remove what we deployed) ---------------------------------------
#
# Removal is name-based and surgical: for each skill/command this repo owns,
# delete the matching file at the destination and nothing else. For CLAUDE.md,
# only the delimited rules block is stripped -- the user's own content stays.
# This mirrors the additive deploy: we never remove files we didn't put there.

# Remove only the skill dirs whose names exist in this repo's skills/.
_remove_named_skills() {
  local dest="$1" name removed=0
  if [[ ! -d "$dest" ]]; then
    echo "  (nothing at $dest)"
    return
  fi
  for name in "$SKILLS_SRC"/*/; do
    name="$(basename "$name")"
    if [[ -e "$dest/$name" ]]; then
      rm -rf "${dest:?}/$name"
      removed=$((removed + 1))
    fi
  done
  rmdir "$dest" 2>/dev/null || true   # only succeeds if now empty
  echo "  Removed $removed skill(s) from $dest"
}

# Remove only the command files whose names exist in this repo's commands/.
_remove_named_commands() {
  local dest="$1" f removed=0
  if [[ ! -d "$dest" ]]; then
    echo "  (nothing at $dest)"
    return
  fi
  for f in "$COMMANDS_SRC"/*.md; do
    if [[ -e "$dest/$(basename "$f")" ]]; then
      rm -f "${dest:?}/$(basename "$f")"
      removed=$((removed + 1))
    fi
  done
  rmdir "$dest" 2>/dev/null || true
  echo "  Removed $removed command(s) from $dest"
}

# Strip the skills rules block from an instructions file (and any
# trailing blank lines it leaves). If that empties the file, delete it.
_clean_rules_at() {
  local target="$1"
  echo "Removing workspace rules block from $target"
  if [[ ! -f "$target" ]] || ! grep -qF "$RULES_BLOCK_START" "$target"; then
    echo "  No skills rules block found; nothing to remove."
    return
  fi
  local tmp; tmp="$(mktemp)"
  awk -v start="$RULES_BLOCK_START" -v end="$RULES_BLOCK_END" '
    $0 == start { skipping=1; next }
    $0 == end { skipping=0; next }
    skipping { next }
    { buf[++n] = $0 }
    END { while (n > 0 && buf[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print buf[i] }
  ' "$target" > "$tmp"
  if grep -q '[^[:space:]]' "$tmp"; then
    mv "$tmp" "$target"
    echo "  Rules block removed; rest of $target left untouched."
  else
    rm -f "$target" "$tmp"
    echo "  Rules block removed; $target was otherwise empty, so it was deleted."
  fi
}

clean_claude_rules()   { _clean_rules_at "$CLAUDE_MD"; }
clean_codex_rules()    { _clean_rules_at "$CODEX_RULES_MD"; }
clean_opencode_rules() { _clean_rules_at "$OPENCODE_RULES_MD"; }

clean_claude_skills() {
  echo "Removing skills → $CLAUDE_SKILLS_DEST"
  _remove_named_skills "$CLAUDE_SKILLS_DEST"
}

clean_claude_commands() {
  echo "Removing commands → $CLAUDE_COMMANDS_DEST"
  _remove_named_commands "$CLAUDE_COMMANDS_DEST"
}

_remove_named_agents() {
  local dest="$1" f removed=0 before
  if [[ ! -d "$dest" ]]; then
    echo "  (nothing at $dest)"
    return
  fi
  for f in "$CLAUDE_AGENTS_SRC"/*.md; do
    if [[ -e "$dest/$(basename "$f")" ]]; then
      rm -f "${dest:?}/$(basename "$f")"
      removed=$((removed + 1))
    fi
  done
  before=$(find "$dest" -maxdepth 1 -type f | wc -l | tr -d ' ')
  _remove_retired_agents "$dest"
  removed=$((removed + before - $(find "$dest" -maxdepth 1 -type f | wc -l | tr -d ' ')))
  rmdir "$dest" 2>/dev/null || true
  echo "  Removed $removed agent(s) from $dest"
}

clean_claude_agents() {
  echo "Removing agents → $CLAUDE_AGENTS_DEST"
  _remove_named_agents "$CLAUDE_AGENTS_DEST"
}

clean_opencode() {
  echo "Removing skills content from OpenCode"
  _remove_named_skills "$OPENCODE_SKILLS_DEST"
  _remove_named_commands "$OPENCODE_COMMANDS_DEST"
  clean_opencode_rules
}

clean_codex() {
  echo "Removing skills content from Codex"
  _remove_named_skills "$AGENTS_SKILLS_DEST"
  clean_codex_rules
}

clean_claude() {
  echo "Removing skills content from Claude Code"
  clean_claude_skills
  clean_claude_commands
  clean_claude_agents
  clean_claude_rules
}

# --- Tool detection & interactive driver -------------------------------------
#
# Registry of supported tools. To add a tool, extend the three case
# statements below (label / detect / deploy) and, if desired, add a shorthand
# to the dispatch. Kept as parallel case functions rather than associative
# arrays so this runs on macOS's stock bash 3.2.

TOOLS="opencode codex claude"

tool_label() {
  case "$1" in
    opencode) echo "OpenCode" ;;
    codex)    echo "Codex" ;;
    claude)   echo "Claude Code" ;;
  esac
}

# Is the tool present? A tool counts as installed if its binary is on PATH or
# its config directory already exists.
detect_tool() {
  case "$1" in
    opencode) command -v opencode >/dev/null 2>&1 || [[ -d "$HOME/.config/opencode" ]] ;;
    codex)    command -v codex    >/dev/null 2>&1 || [[ -d "$HOME/.codex" ]] || [[ -d "$HOME/.agents" ]] ;;
    claude)   command -v claude   >/dev/null 2>&1 || [[ -d "$CLAUDE_DIR" ]] ;;
  esac
}

# Human-readable note on WHERE the tool was detected (for the scan summary).
tool_where() {
  case "$1" in
    opencode) command -v opencode >/dev/null 2>&1 && { echo "on PATH"; return; }; echo "$HOME/.config/opencode" ;;
    codex)    command -v codex    >/dev/null 2>&1 && { echo "on PATH"; return; }; [[ -d "$HOME/.codex" ]] && { echo "$HOME/.codex"; return; }; echo "$HOME/.agents" ;;
    claude)   command -v claude   >/dev/null 2>&1 && { echo "on PATH"; return; }; echo "$CLAUDE_DIR" ;;
  esac
}

deploy_tool() {
  case "$1" in
    opencode) deploy_skills; deploy_commands; deploy_opencode_rules ;;
    codex)    deploy_codex_skills; deploy_codex_rules ;;
    claude)   deploy_claude ;;
  esac
}

clean_tool() {
  case "$1" in
    opencode) clean_opencode ;;
    codex)    clean_codex ;;
    claude)   clean_claude ;;
  esac
}

# Does dest contain any skill dir this repo owns?
_dest_has_our_skills() {
  local dest="$1" name
  [[ -d "$dest" ]] || return 1
  for name in "$SKILLS_SRC"/*/; do
    [[ -e "$dest/$(basename "$name")" ]] && return 0
  done
  return 1
}

# Does dest contain any command file this repo owns?
_dest_has_our_commands() {
  local dest="$1" f
  [[ -d "$dest" ]] || return 1
  for f in "$COMMANDS_SRC"/*.md; do
    [[ -e "$dest/$(basename "$f")" ]] && return 0
  done
  return 1
}

# Does dest contain any agent file this repo owns?
_dest_has_our_agents() {
  local dest="$1" f record name expected actual
  [[ -d "$dest" ]] || return 1
  for f in "$CLAUDE_AGENTS_SRC"/*.md; do
    [[ -e "$dest/$(basename "$f")" ]] && return 0
  done
  for record in $RETIRED_CLAUDE_AGENTS; do
    name="${record%%:*}"
    expected="${record#*:}"
    [[ -f "$dest/$name" && ! -L "$dest/$name" ]] || continue
    actual="$(_sha256_file "$dest/$name")" || continue
    [[ "$actual" == "$expected" ]] && return 0
  done
  return 1
}

# Does this instructions file carry our rules block?
_dest_has_our_rules() {
  [[ -f "$1" ]] && grep -qF "$RULES_BLOCK_START" "$1"
}

# Has this tool actually received any skills content? (Used by cleanup
# so it only prompts for tools that have something to remove.)
detect_deployed() {
  case "$1" in
    opencode) _dest_has_our_skills "$OPENCODE_SKILLS_DEST" || _dest_has_our_commands "$OPENCODE_COMMANDS_DEST" \
                || _dest_has_our_rules "$OPENCODE_RULES_MD" ;;
    codex)    _dest_has_our_skills "$AGENTS_SKILLS_DEST" || _dest_has_our_rules "$CODEX_RULES_MD" ;;
    claude)   _dest_has_our_skills "$CLAUDE_SKILLS_DEST" || _dest_has_our_commands "$CLAUDE_COMMANDS_DEST" \
                || _dest_has_our_agents "$CLAUDE_AGENTS_DEST" \
                || _dest_has_our_rules "$CLAUDE_MD" ;;
  esac
}

# Yes/no prompt, defaulting to yes on empty input.
confirm() {
  local reply
  printf '%s ' "$1"
  read -r reply || return 1
  case "$reply" in
    [Nn]|[Nn][Oo]) return 1 ;;
    *)             return 0 ;;
  esac
}

# Yes/no prompt defaulting to NO (for destructive actions like cleanup).
confirm_no() {
  local reply
  printf '%s ' "$1"
  read -r reply || return 1
  case "$reply" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *)                 return 1 ;;
  esac
}

# The easy path: scan, then deploy to each detected tool.
# $1 = "yes" to skip prompts (accept all detected).
run_auto() {
  local assume_yes="${1:-no}"
  local detected="" undetected="" t

  echo "Scanning for installed AI coding tools..."
  for t in $TOOLS; do
    if detect_tool "$t"; then detected="$detected $t"; else undetected="$undetected $t"; fi
  done
  detected="${detected# }"
  undetected="${undetected# }"

  if [[ -z "$detected" ]]; then
    echo "No supported tools detected (looked for OpenCode, Codex, Claude Code)."
    echo "Install one and re-run, or deploy explicitly: ./setup.sh <opencode|codex|claude>"
    return 0
  fi

  echo "Detected:"
  for t in $detected; do
    echo "  - $(tool_label "$t")  ($(tool_where "$t"))"
  done
  echo

  # Non-interactive (piped stdin) implies accept-all so the script never hangs.
  if [[ ! -t 0 ]]; then assume_yes="yes"; fi

  local any=0
  for t in $detected; do
    local label; label="$(tool_label "$t")"
    if [[ "$assume_yes" == "yes" ]]; then
      echo "→ Deploying to $label"
      deploy_tool "$t"; any=1
    elif confirm "Deploy skills/commands/rules to $label? [Y/n]"; then
      deploy_tool "$t"; any=1
    else
      echo "  Skipped $label"
    fi
    echo
  done

  if [[ -n "$undetected" ]]; then
    echo "Not detected (install it, then run ./setup.sh <tool>):"
    for t in $undetected; do echo "  - $(tool_label "$t")"; done
    echo
  fi

  [[ "$any" == 1 ]] && echo "Setup complete."
  return 0
}

# The cleanup counterpart: scan for deployed content, then remove per tool.
# $1 = "yes" to skip prompts (remove from all found).
run_clean() {
  local assume_yes="${1:-no}"
  local found="" t

  echo "Scanning for deployed skills content..."
  for t in $TOOLS; do
    detect_deployed "$t" && found="$found $t"
  done
  found="${found# }"

  if [[ -z "$found" ]]; then
    echo "Nothing deployed by skills was found. Nothing to clean."
    return 0
  fi

  echo "Found deployed content for:"
  for t in $found; do
    echo "  - $(tool_label "$t")"
  done
  echo

  # Cleanup is destructive: never auto-remove non-interactively unless -y was
  # given explicitly. (Deploy assumes-yes when piped; cleanup refuses.)
  if [[ "$assume_yes" != "yes" && ! -t 0 ]]; then
    echo "Refusing to remove content non-interactively without -y."
    echo "Re-run with:  ./cleanup.sh -y   (or target one tool: ./cleanup.sh claude)"
    return 0
  fi

  local any=0
  for t in $found; do
    local label; label="$(tool_label "$t")"
    if [[ "$assume_yes" == "yes" ]]; then
      echo "→ Cleaning $label"
      clean_tool "$t"; any=1
    elif confirm_no "Remove skills content from $label? [y/N]"; then
      clean_tool "$t"; any=1
    else
      echo "  Kept $label"
    fi
    echo
  done

  [[ "$any" == 1 ]] && echo "Cleanup complete."
  return 0
}

# Sub-dispatch for `clean` (invoked directly or via cleanup.sh).
run_clean_dispatch() {
  case "${1:-}" in
    ""|auto)          run_clean no ;;
    -y|--yes|yes)     run_clean yes ;;
    opencode)         clean_opencode ;;
    codex)            clean_codex ;;
    claude)           clean_claude ;;
    claude-skills)    clean_claude_skills ;;
    claude-commands)  clean_claude_commands ;;
    claude-agents)    clean_claude_agents ;;
    claude-rules)     clean_claude_rules ;;
    codex-rules)      clean_codex_rules ;;
    opencode-rules)   clean_opencode_rules ;;
    help|--help|-h)   usage ;;
    *)                echo "Unknown clean target: $1"; usage; exit 1 ;;
  esac
}

case "${1:-auto}" in
  auto)
    case "${2:-}" in -y|--yes|yes) run_auto yes ;; *) run_auto no ;; esac ;;
  -y|--yes)                run_auto yes ;;
  opencode)                deploy_skills; deploy_commands; deploy_opencode_rules ;;
  codex)                   deploy_codex_skills; deploy_codex_rules ;;
  claude)                  deploy_claude ;;
  setup)                   deploy_all_skills && deploy_commands && deploy_opencode_rules \
                             && deploy_codex_rules && deploy_claude && echo "Setup complete." ;;
  clean)                   run_clean_dispatch "${2:-}" ;;
  deploy-skills)           deploy_skills ;;
  deploy-codex-skills)     deploy_codex_skills ;;
  deploy-all-skills)       deploy_all_skills ;;
  deploy-commands)         deploy_commands ;;
  deploy-claude)           deploy_claude ;;
  deploy-claude-skills)    deploy_claude_skills ;;
  deploy-claude-commands)  deploy_claude_commands ;;
  deploy-claude-agents)    deploy_claude_agents ;;
  deploy-claude-rules)     deploy_claude_rules ;;
  deploy-codex-rules)      deploy_codex_rules ;;
  deploy-opencode-rules)   deploy_opencode_rules ;;
  diff-skills)             diff_skills ;;
  diff-codex-skills)       diff_codex_skills ;;
  diff-commands)           diff_commands ;;
  diff-claude-skills)      diff_claude_skills ;;
  diff-claude-commands)    diff_claude_commands ;;
  diff-claude-agents)      diff_claude_agents ;;
  diff-claude-rules)       diff_claude_rules ;;
  diff-codex-rules)        diff_codex_rules ;;
  diff-opencode-rules)     diff_opencode_rules ;;
  help|--help|-h)          usage ;;
  *)                       echo "Unknown command: $1"; usage; exit 1 ;;
esac
