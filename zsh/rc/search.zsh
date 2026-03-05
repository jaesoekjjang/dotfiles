rgt() {
  local INITIAL_QUERY="$*"
  
  # glob 패턴을 사용할 때 이스케이핑을 하거나 따옴표로 감싸야 함. (e.g, -g='!**/*.ts')
  fzf --ansi \
      --disabled \
      --query "$INITIAL_QUERY" \
      --bind "change:reload:sleep 0.1; eval rg --column --line-number --no-heading --color=always --smart-case {q} 2>/dev/null || true" \
      --bind "start:reload:eval rg --column --line-number --no-heading --color=always --smart-case {q} 2>/dev/null || true" \
      --bind "ctrl-f:preview-half-page-down" \
      --bind "ctrl-b:preview-half-page-up" \
      --bind "ctrl-o:execute-silent(open_editor {1} {2})" \
      --bind "enter:execute-silent(open_editor {1} {2})" \
      --delimiter : \
      --preview 'bat --color=always --style=numbers,changes --highlight-line {2} {1}' \
      --preview-window 'up,75%,border-bottom,+{2}+3/3,~3' \
      --header '🔍 Telescope | 예: --type=py -i search | Enter: 편집 | ESC: 종료' \
}