
rgf() {
  local RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case"
  local QUERY=""
  local RG_OPTS=""

  if [[ $# -eq 0 ]]; then
    echo "❌ 사용법: rgf [옵션] <검색어>"
    return 1
  elif [[ $# -eq 1 ]]; then
    QUERY="$1"
  else
    QUERY="${@[-1]}"
    RG_OPTS="${@[1,-2]}"
  fi

  local FINAL_PREFIX="$RG_PREFIX $RG_OPTS"

  # fzf 실행 결과(선택된 라인)를 변수에 담음
  local result
  result=$(fzf --ansi \
      --disabled \
      --query "$QUERY" \
      --bind "start:reload:$FINAL_PREFIX {q} || true" \
      --bind "change:reload:sleep 0.1; $FINAL_PREFIX {q} || true" \
      --bind "ctrl-f:preview-half-page-down" \
      --bind "ctrl-b:preview-half-page-up" \
      --bind "ctrl-o:execute-silent(open_editor {1} {2})"
      --bind "enter:execute-silent(open_editor {1} {2})" \
      --delimiter : \
      --preview 'bat --color=always --style=numbers,changes --highlight-line {2} {1} 2>/dev/null' \
      --preview-window 'up,75%,border-bottom,+{2}+3/3,~0' \
      --header "🔍 옵션: [${RG_OPTS:-없음}] | C-d/u: 스크롤 | Enter: 선택" \
      --exit-0)

  # 선택된 결과가 있으면 파일명:줄번호 형식으로 출력
  if [[ -n "$result" ]]; then
    echo "$result" | cut -d: -f1,2
  fi
}

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