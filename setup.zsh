#!/bin/zsh

set -e

export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
export DOTFILES="$ICLOUD_DIR/Dotfiles"

# .zshrc, .zprofile
ln -sf "$DOTFILES/zsh/.zshenv" "$HOME/.zshenv"
ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"

# tmux
ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"

# workmux
ln -sf "$DOTFILES/workmux/config.yaml" "$HOME/.config/workmux/config.yaml"


# lazygit
mkdir -p "$HOME/Library/Application Support/lazygit"
ln -sf "$DOTFILES/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

# yazi
ln -sfn "$DOTFILES/yazi" ~/.config/yazi

# ghostty
mkdir -p ~/.config
ln -sfn "$DOTFILES/ghostty" ~/.config/ghostty

# local bin
mkdir -p "$HOME/.local/bin"
for f in "$DOTFILES/bin"/*; do
  [[ -f "$f" ]] && chmod +x "$f" && ln -sf "$f" "$HOME/.local/bin/"
done

# git
ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"

# claude code
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES/claude/agents" "$HOME/.claude/agents"
ln -sf "$DOTFILES/claude/commands" "$HOME/.claude/commands"
ln -sf "$DOTFILES/claude/skills" "$HOME/.claude/skills"
ln -sf "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"

# secrets (로컬 전용, 존재하지 않을 때만 생성)
[[ ! -f ~/.secrets.zsh ]] && touch ~/.secrets.zsh
