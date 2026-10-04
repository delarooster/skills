---
name: tidy
description: Cleans up after a story loop or any multi-worktree session. Removes finished git worktrees, stops their leftover containers, prunes stale state, and reports what it left alone. Use when asked to "tidy", "clean up worktrees", or at the end of a loop batch.
tools: Bash, Read, Glob
model: haiku
---

# TIDY

Run the script below once, exactly as written, with the values from the brief.
Then return its output verbatim. Do not summarise, count or edit it, and do not
act on any worktree yourself.

```bash
REPO="<repo path>"; INTEGRATION="<integration branch>"; KEEP="<space-separated worktree dir names to keep>"
cd "$REPO" || exit 1
before=$(git worktree list | wc -l | tr -d ' ')
git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r wt; do
  name=$(basename "$wt")
  [ "$wt" = "$(git rev-parse --show-toplevel)" ] && continue
  case " $KEEP " in *" $name "*) echo "KEPT $name -- in flight"; continue;; esac
  [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" = "$INTEGRATION" ] && { echo "KEPT $name -- integration"; continue; }
  [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ] && { echo "KEPT $name -- dirty"; continue; }
  git merge-base --is-ancestor "$(git -C "$wt" rev-parse HEAD)" "$INTEGRATION" || { echo "KEPT $name -- unmerged"; continue; }
  docker compose ls -q 2>/dev/null | grep -qx "$name" && docker compose -p "$name" down >/dev/null 2>&1 && echo "STOPPED $name"
  git worktree remove "$wt" && echo "REMOVED $name"
done
git worktree prune
echo "WORKTREES: $before -> $(git worktree list | wc -l | tr -d ' ')"
echo "MERGED BRANCHES: $(git branch --merged "$INTEGRATION" | grep -v -e "$INTEGRATION" -e '^\*' -e '^+' | wc -l | tr -d ' ') (list with: git branch --merged $INTEGRATION)"
```

## Never

`git branch -d/-D`, `reset`, `clean`, `stash`, push, `worktree remove --force`,
`docker compose down -v`, volume or image deletion, `supabase stop --no-backup`.
A worktree the script keeps stays kept.
