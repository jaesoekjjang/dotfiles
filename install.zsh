#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail

dotfiles_root=${0:A:h}
desktop=true
agents=true
languages=false
while (( $# )); do
  case "$1" in
    --cli-only) desktop=false ;;
    --no-agents) agents=false ;;
    --with-languages) languages=true ;;
    -h|--help)
      print 'install.zsh [--cli-only] [--no-agents] [--with-languages]'
      print '설치 후 ./setup.zsh 실행. 기존 shell plugin checkout과 설정은 보존합니다.'
      exit ;;
    *) print -u2 -- "알 수 없는 옵션: $1"; exit 2 ;;
  esac
  shift
done

[[ "$OSTYPE" == darwin* ]] || { print -u2 'macOS용 설치입니다.'; exit 1; }
xcode-select -p >/dev/null 2>&1 || {
  print -u2 '먼저 xcode-select --install로 Command Line Tools를 설치하세요.'
  exit 1
}
if [[ "$CPUTYPE" == arm64 && -x /opt/homebrew/bin/brew &&
      "${commands[brew]:-}" == (''|/usr/local/bin/brew|/opt/homebrew/bin/brew) ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif (( $+commands[brew] )); then
  eval "$(brew shellenv)"
elif [[ "$CPUTYPE" == arm64 && -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  print -u2 'Homebrew가 필요합니다: https://brew.sh (설치 후 다시 실행)'
  exit 1
fi

# Homebrew 7 requires explicit trust. Scope it to these packages, not entire taps.
if brew help trust >/dev/null 2>&1; then
  brew trust --formula raine/workmux/workmux
  if $desktop; then
    brew trust --formula felixkratz/formulae/borders
    brew trust --cask nikitabobko/tap/aerospace
  fi
fi
brew bundle --file="$dotfiles_root/Brewfile"
# A standalone Python avoids depending on the host macOS libexpat ABI.
path=("$HOME/.local/bin" "${path[@]}")
uv python install "$(cat "$dotfiles_root/.python-version")" --default
python3 -c 'import pyexpat, ensurepip'
if $desktop; then
  brew bundle --file="$dotfiles_root/Brewfile.desktop"
fi
if $languages; then
  brew bundle --file="$dotfiles_root/Brewfile.languages"
fi

# Install a known checkout on a fresh machine; never reset an existing checkout.
while IFS=$'\t' read -r repository revision destination; do
  [[ -n "$repository" && "$repository" != \#* ]] || continue
  destination="$HOME/$destination"
  if [[ -e "$destination" || -L "$destination" ]]; then
    print -r -- "기존 plugin 보존: $destination"
    continue
  fi
  mkdir -p "${destination:h}"
  staging=$(mktemp -d "${destination:h}/.dotfiles-plugin.XXXXXX")
  if git -C "$staging" init -q &&
    git -C "$staging" remote add origin "https://github.com/$repository.git" &&
    git -C "$staging" fetch -q --depth=1 origin "$revision" &&
    git -C "$staging" checkout -q --detach FETCH_HEAD; then
    mv "$staging" "$destination"
  else
    rm -rf -- "$staging"
    print -u2 -- "Plugin 설치 실패: $repository"
    exit 1
  fi
done < "$dotfiles_root/bootstrap/plugins.tsv"

# Use this repository's supported major; leave project version files unchanged.
export FNM_COREPACK_ENABLED=false
eval "$(fnm env --shell zsh)"
node_major=$(cat "$dotfiles_root/.node-version")
fnm install "$node_major"
fnm use "$node_major"
fnm default "$(node --version)"
npm install -g corepack
corepack enable pnpm

# Native agent binaries avoid dependence on a project's Node version.
if $agents; then
  (( $+commands[codex] )) || brew install --cask codex
  (( $+commands[claude] )) || brew install --cask claude-code
  tuios integration install codex
fi
print '설치 완료. ./setup.zsh → 새 shell → dotfiles-doctor 순서로 확인하세요.'
