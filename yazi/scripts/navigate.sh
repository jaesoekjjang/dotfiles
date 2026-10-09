#!/usr/bin/env bash

set -euo pipefail

on_error() {
  local result=$?
  printf '\nYazi command failed (exit %s).\n' "$result" >&2
  if [[ -t 0 ]]; then
    read -r -p 'Press Enter to return to Yazi. ' _ || true
  fi
  exit "$result"
}
trap on_error ERR

mode=${1:?navigation action required}
entry=${2:-$PWD}
if [[ -d "$entry" ]]; then
  directory=$entry
else
  directory=$(dirname -- "$entry")
fi

pick_session() {
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}') || return 2
  printf '%s\n' "$sessions" | fzf --prompt='tmux session> '
}

require_tmux_client() {
  if [[ -z "${TMUX:-}" ]]; then
    echo 'This command requires Yazi to run inside tmux.' >&2
    return 1
  fi
}

case "$mode" in
  git-root)
    root=$(git rev-parse --show-toplevel)
    ya emit cd "$root"
    ;;
  project)
    script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
    projects=$("$script_dir/../../bin/workspace" _projects)
    if row=$(printf '%s\n' "$projects" | fzf --prompt='project> ' \
      --delimiter=$'\t' --with-nth=2,3 --nth=1,2 --extended); then
      [[ -n "$row" ]] && ya emit cd "${row%%$'\t'*}"
    else
      result=$?
      [[ "$result" == 1 || "$result" == 130 ]] || exit "$result"
    fi
    ;;
  ghostty)
    open -na Ghostty --args "--working-directory=$directory"
    ;;
  tmux-window)
    require_tmux_client
    tmux new-window -c "$directory"
    ;;
  tmux-pick-window|tmux-switch)
    if [[ "$mode" == tmux-switch ]]; then require_tmux_client; fi
    if session=$(pick_session); then
      [[ -n "$session" ]] || exit 0
      if [[ "$mode" == tmux-switch ]]; then
        tmux switch-client -t "=$session"
      else
        tmux new-window -t "=$session" -c "$directory"
      fi
    else
      result=$?
      [[ "$result" == 1 || "$result" == 130 ]] || exit "$result"
    fi
    ;;
  tmux-session)
    if [[ -n "${TMUX:-}" ]]; then
      session=$(tmux new-session -d -P -F '#{session_id}' -c "$directory")
      tmux switch-client -t "$session"
    else
      tmux new-session -c "$directory"
    fi
    ;;
  *) echo "Unknown navigation action: $mode" >&2; exit 1 ;;
esac
