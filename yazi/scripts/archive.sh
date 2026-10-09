#!/usr/bin/env bash

mode=${1:?archive operation required}
shift
result_path=
cancelled=false

archive() {
  command -v atool >/dev/null || { echo 'atool is not installed.' >&2; return 127; }
  (( $# )) || { echo 'No files selected.' >&2; return 1; }

  local file output parent current_dir suggested
  local -a files=() options=()
  current_dir=$(pwd -P)
  # Yazi supplies absolute paths. Keep archive members relative to the cwd.
  for file in "$@"; do
    if [[ "$file" == /* ]]; then
      parent=${file%/*}
      parent=$(cd -- "${parent:-/}" && pwd -P) || return
      if [[ "$parent" == "$current_dir" ]]; then
        file="./${file##*/}"
      elif [[ "$parent" == "$current_dir/"* ]]; then
        file="./${parent#"$current_dir/"}/${file##*/}"
      fi
    fi
    files+=("$file")
  done
  if command -v 7zz >/dev/null; then
    options+=(--option path_7z=7zz)
  fi

  case "$mode" in
    zip|tar|tar.gz)
      suggested="archive.$mode"
      if (( ${#files[@]} == 1 )); then
        suggested=${files[0]##*/}
        [[ -f "${files[0]}" && "$suggested" != .* ]] && suggested=${suggested%.*}
        suggested="$suggested.$mode"
      fi
      output=$suggested
      if [[ -t 0 ]]; then
        printf '\n결과 파일명 [%s] (Enter: 기본 이름, Ctrl-d: 취소): ' "$suggested"
        IFS= read -r output || { cancelled=true; return 0; }
        output=${output:-$suggested}
      fi
      [[ "$output" == *".$mode" ]] || output="$output.$mode"
      if [[ "$output" == */* ]]; then
        echo '현재 폴더에 저장할 파일명만 입력하세요.' >&2
        return 1
      fi
      if [[ -e "$output" || -L "$output" ]]; then
        echo "$output already exists. Rename it before creating another archive." >&2
        return 1
      fi
      atool "${options[@]}" --add -- "./$output" "${files[@]}" || return
      result_path="$current_dir/$output"
      ;;
    extract)
      # Process every selected archive; expose overwrite prompts in the terminal.
      atool "${options[@]}" --extract-to=. --each -- "${files[@]}"
      ;;
    extract-dir)
      atool "${options[@]}" --extract --subdir --each -- "${files[@]}"
      ;;
    *) echo "Unknown archive operation: $mode" >&2; return 1 ;;
  esac
}

archive "$@"
result=$?
if [[ "$cancelled" == true ]]; then
  exit 0
elif (( result != 0 )); then
  printf '\nArchive operation failed (exit %s). Press Enter to return to Yazi.\n' "$result" >&2
  [[ -t 0 ]] && read -r _
else
  if [[ -n "$result_path" ]]; then
    printf '\n압축 완료: %s\n저장 위치: %s\n' "${result_path##*/}" "$result_path"
    if [[ -n "${YAZI_ID:-}" ]]; then
      ya emit reveal "$result_path" >/dev/null 2>&1 || true
    fi
  else
    printf '\n해제 완료. 결과 위치: %s\n' "$(pwd -P)"
  fi
  if [[ -t 0 ]]; then
    printf 'Enter를 누르면 Yazi로 돌아갑니다.\n'
    read -r _
  fi
fi
exit "$result"
