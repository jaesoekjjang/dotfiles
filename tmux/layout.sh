#!/usr/bin/env bash

CHOICE=$(printf 'main-vertical\nmain-horizontal\neven-horizontal\neven-vertical\ntiled\ndev [20|60|20↕]' \
  | fzf --reverse --prompt='layout> ')

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
  "dev [20|60|20↕]")
    DIR=$(tmux display-message -p "#{pane_current_path}")
    tmux split-window -h -c "$DIR"
    tmux split-window -h -c "$DIR"
    tmux select-layout even-horizontal
    tmux resize-pane -t 1 -x "20%"
    tmux resize-pane -t 3 -x "20%"
    tmux select-pane -t 3
    tmux split-window -v -c "$DIR"
    tmux select-pane -t 2
    ;;
  *)
    tmux select-layout "$CHOICE"
    ;;
esac
