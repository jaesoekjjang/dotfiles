tmux_project() {
  emulate -L zsh
  local raw_name
  raw_name=$(basename "$PWD")
  local session_name
  session_name=$(printf '%s' "$raw_name" | sed 's/[^a-zA-Z0-9_-]/_/g')
  if tmux has-session -t "$session_name" 2>/dev/null; then
    tmux attach-session -t "$session_name"
    return
  fi
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # 0: lazygit
    tmux new-session -s "$session_name" -n git -d 'lazygit'
    # 1: claude (번호 자동 배정)
    tmux new-window -t "$session_name" -n claude
    tmux send-keys -t "${session_name}:claude" 'claude' Enter
    # 2: shell (vsplit)
    tmux new-window -t "$session_name" -n shell
    tmux split-window -h -t "${session_name}:shell"
    # lazygit에 포커스
    tmux select-window -t "${session_name}:git"
  else
    tmux new-session -s "$session_name" -n shell -d
    tmux split-window -h -t "${session_name}:shell"
  fi
  tmux attach-session -t "$session_name"
}