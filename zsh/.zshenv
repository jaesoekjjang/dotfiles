# 정적 env
export EDITOR="nvim"
export VISUAL="nvim"

export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
export DOTFILES="${${(%):-%x}:A:h:h}"

typeset -U path PATH
# Prefer native Homebrew tools even in non-login shells (tmux/TUIOS).
if [[ "$CPUTYPE" == arm64 && -d /opt/homebrew/bin ]]; then
  path=(/opt/homebrew/bin /opt/homebrew/sbin "${path[@]}")
elif [[ -d /usr/local/bin ]]; then
  path=(/usr/local/bin /usr/local/sbin "${path[@]}")
fi
export PATH="$HOME/.local/bin:$PATH"
# 로컬 오버라이드(있으면)
[[ -f "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
