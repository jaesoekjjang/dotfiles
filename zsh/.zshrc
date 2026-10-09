# TUIOS daemons can retain a runner's NO_COLOR; interactive panes need colors.
[[ -n "${TUIOS_SESSION:-}" ]] && unset NO_COLOR

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
#
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# oh-my-zsh

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git
  zsh-autosuggestions
  zsh-syntax-highlighting

  kubectl
  docker
  docker-compose
  brew

  extract
  jsontools
  web-search
  colored-man-pages
  aliases
  alias-finder
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  print -u2 'oh-my-zsh가 없습니다. dotfiles/install.zsh를 실행하세요.'
fi
source "$DOTFILES/zsh/rc/index.zsh"
(( $+commands[fzf] )) && source <(fzf --zsh)

export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git/*' --glob '!node_modules/*'"

export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

export FZF_CTRL_R_OPTS="
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"

(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

(( $+parameters[ZSH_HIGHLIGHT_STYLES] )) && ZSH_HIGHLIGHT_STYLES[comment]='fg=cyan,bold'

# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r "$HOME/.opam/opam-init/init.zsh" ]] || source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
# END opam configuration
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# 초기 Node 환경 생성은 조용하게, 이후 자동 전환은 오류만 출력합니다.
# fnm 로그 수준은 p10k의 Node 버전 표시와 별개입니다.
# 부모 셸이나 tmux에서 상속된 fnm 경로는 새 환경으로 교체합니다.
path=("${(@)path:#*/fnm_multishells/*/bin}")
export FNM_COREPACK_ENABLED=true
(( $+commands[fnm] )) && eval "$(fnm env --use-on-cd --shell zsh --log-level quiet)"
export FNM_LOGLEVEL=error

export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# 독립 설치한 CLI는 프로젝트의 Node 버전과 관계없이 사용합니다.
path=("$HOME/.local/bin" "${path[@]}")
