#!/bin/zsh

set -e

export DOTFILES="${0:A:h}"
export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
refresh_tuios=false
case "${1:-}" in
  '') ;;
  --refresh-tuios) refresh_tuios=true ;;
  -h|--help) print 'setup.zsh [--refresh-tuios]'; exit ;;
  *) print -u2 -- "알 수 없는 옵션: $1"; exit 2 ;;
esac
(( $# <= 1 )) || { print -u2 '옵션은 하나만 지정하세요.'; exit 2; }

# 기존 파일은 보관하고, 디렉터리 링크는 따라가지 않습니다.
backup_dir="$HOME/.local/state/dotfiles-backups/setup-$(date +%Y%m%d-%H%M%S)-$$"
backup_existing() {
  mkdir -p "$backup_dir"
  chmod 700 "$backup_dir"
  mv "$1" "$backup_dir/${1:t}-$RANDOM"
}

link_config() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || { print -u2 "Missing source: $src"; return 1; }
  mkdir -p "${dest:h}"
  if [[ -e "$dest" || -L "$dest" ]]; then
    [[ "${src:A}" == "${dest:A}" ]] && return 0
    backup_existing "$dest"
  fi
  ln -sfn "$src" "$dest"
}

# 설치 도구가 새 파일을 쓰는 디렉터리는 실제 로컬 디렉터리로 둡니다.
local_directory() {
  local dest="$1" src entry
  if [[ -L "$dest" ]]; then
    src="${dest:A}"
    [[ -d "$src" ]] || { print -u2 "Broken directory link: $dest"; return 1; }
    backup_existing "$dest"
    mkdir -p "$dest"
    for entry in "$src"/*(DN); do
      [[ -e "$entry" ]] && ln -s "$entry" "$dest/${entry:t}"
    done
  else
    mkdir -p "$dest"
  fi
  return 0
}

mkdir -p "$HOME/.config/workmux" "$HOME/Library/Application Support/lazygit"
for name in .zshenv .zshrc .zprofile; do
  link_config "$DOTFILES/zsh/$name" "$HOME/$name"
done
link_config "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
if [[ -L "$HOME/.tmux/layout.sh" && "$(readlink "$HOME/.tmux/layout.sh")" == "$DOTFILES/tmux/layout.sh" ]]; then
  rm "$HOME/.tmux/layout.sh"
fi
link_config "$DOTFILES/workmux/config.yaml" "$HOME/.config/workmux/config.yaml"
# TUIOS rewrites Settings. Keep its runtime config out of the Git checkout.
tuios_config="$HOME/Library/Application Support/tuios/config.toml"
mkdir -p "${tuios_config:h}"
if [[ -L "$tuios_config" ]]; then
  # Keep the current contents even if this is a link to an older checkout.
  temporary=$(mktemp "${tuios_config:h}/.config.XXXXXX")
  if [[ -f "$tuios_config" ]]; then
    cp "$tuios_config" "$temporary"
  else
    cp "$DOTFILES/tuios/config.toml" "$temporary"
  fi
  backup_existing "$tuios_config"
  mv "$temporary" "$tuios_config"
elif [[ ! -e "$tuios_config" ]]; then
  cp "$DOTFILES/tuios/config.toml" "$tuios_config"
fi
if $refresh_tuios && ! cmp -s "$DOTFILES/tuios/config.toml" "$tuios_config"; then
  backup_existing "$tuios_config"
  cp "$DOTFILES/tuios/config.toml" "$tuios_config"
fi
link_config "$DOTFILES/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
for name in yazi ghostty nvim aerospace; do
  link_config "$DOTFILES/$name" "$HOME/.config/$name"
done

local_directory "$HOME/.local/bin"
if [[ -L "$HOME/.local/bin/cc-arm64" && "$(readlink "$HOME/.local/bin/cc-arm64")" == "$DOTFILES/bin/cc-arm64" ]]; then
  rm "$HOME/.local/bin/cc-arm64"
fi
for name in open_editor edit_files setup zsh_reload workspace tuios-trial tuios-picker dotfiles-doctor; do
  [[ -f "$DOTFILES/bin/$name" ]] || continue
  chmod +x "$DOTFILES/bin/$name"
  link_config "$DOTFILES/bin/$name" "$HOME/.local/bin/$name"
done

link_config "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
mkdir -p "$HOME/.claude"
for name in agents commands; do
  local_directory "$HOME/.claude/$name"
  for entry in "$DOTFILES/claude/$name"/*(DN); do
    if [[ -e "$entry" ]]; then
      link_config "$entry" "$HOME/.claude/$name/${entry:t}"
    else
      print -u2 "Skipping unavailable source: $entry"
    fi
  done
done
link_config "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link_config "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
link_config "$DOTFILES/claude/statusline.sh" "$HOME/.claude/statusline-command.sh"

# Keep an existing personal prompt; fresh machines get a small shared default.
[[ -e "$HOME/.p10k.zsh" || -L "$HOME/.p10k.zsh" ]] || link_config "$DOTFILES/zsh/p10k.zsh" "$HOME/.p10k.zsh"

if [[ ! -f "$HOME/.secrets.zsh" ]]; then
  (umask 077; touch "$HOME/.secrets.zsh")
fi
chmod 600 "$HOME/.secrets.zsh"
