tmux_project() {
  emulate -L zsh
  local raw_name
  raw_name=$(basename "$PWD")
  local session_name
  session_name=$(printf '%s' "$raw_name" | sed 's/[^a-zA-Z0-9_-]/_/g')
  
  # 현재 경로를 변수에 저장
  local current_dir="$PWD"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    tmux attach-session -t "$session_name"
    return
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # -c 옵션을 추가하여 tmux가 해당 경로에서 시작하도록 강제합니다.
    tmux new-session -s "$session_name" -n git -d -c "$current_dir" 'lazygit'
    tmux new-window -t "$session_name" -n shell -c "$current_dir"
    tmux split-window -h -t "${session_name}:shell" -c "$current_dir"
    tmux select-window -t "${session_name}:git"
  else
    tmux new-session -s "$session_name" -n shell -d -c "$current_dir"
    tmux split-window -h -t "${session_name}:shell" -c "$current_dir"
  fi
  tmux attach-session -t "$session_name"
}
