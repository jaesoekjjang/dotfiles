# 정적 env
export EDITOR="cursor"
export VISUAL="nvim"
export TERM=xterm-256color

export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
export DOTFILES="$ICLOUD_DIR/Dotfiles"

export PATH="$HOME/.local/bin:$PATH"
# 로컬 오버라이드(있으면)
[[ -f "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"