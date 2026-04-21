# hammerspoon:// URL 스킴 생성 + 실행
# 사용: hs <action> [key=value ...]
#   hs file path=/abs/path line=42       → 클립보드에 URL 복사
#   hs file path=/abs/path line=42 --run → 바로 실행
hs() {
  local action="$1"; shift
  if [[ -z "$action" ]]; then
    echo "usage: hs <action> [key=value ...] [--run]" >&2
    return 1
  fi

  local run=false
  local params=()
  for arg in "$@"; do
    if [[ "$arg" == "--run" ]]; then
      run=true
    else
      params+=("$arg")
    fi
  done

  local url="hammerspoon://${action}"
  if (( ${#params[@]} )); then
    url+="?${(j:&:)params}"
  fi

  if $run; then
    open "$url"
  else
    echo -n "$url" | pbcopy
    echo "copied: $url"
  fi
}
