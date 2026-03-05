#!/bin/zsh

set -e

HOMEBREW_NO_AUTO_UPDATE=1 brew install \
  zsh \
  `# CLI 대체 도구 (bat=cat, eza=ls, ripgrep=grep, fd=find, btop=top, sevenzip=tar/zip, tealdeer=tldr)` \
  bat eza ripgrep fd btop sevenzip tealdeer \
  `# 탐색 & 파일 관리` \
  fzf yazi zoxide \
  `# git` \
  lazygit git-cliff delta \
  `# 터미널 환경` \
  tmux fnm \
  `# 문서 & 미디어` \
  glow poppler resvg ffmpegthumbnailer \
  `# 개발 도구` \
  mkcert jq httpie

# oh-my-zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# npm
npm install -g commitizen
