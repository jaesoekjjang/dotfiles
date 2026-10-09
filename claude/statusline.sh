#!/bin/sh
set -eu
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
# Literal ~ is display text, not a filesystem path.
# shellcheck disable=SC2088
case "$cwd" in
  "$HOME") directory='~' ;;
  "$HOME"/*) directory="~/${cwd#"$HOME"/}" ;;
  *) directory="$cwd" ;;
esac
branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null ||
  git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)
printf '\033[34m%s\033[0m' "$directory"
if [ -n "$branch" ]; then printf ' \033[32m(%s)\033[0m' "$branch"; fi
if [ -n "$model" ]; then printf ' \033[90m| %s\033[0m' "$model"; fi
if [ -n "$used" ]; then printf ' | ctx:%s%%' "$used"; fi
printf '\n'
