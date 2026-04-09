# system, core apps
alias rm="rm -i"
alias cp="cp -i"
alias md="mkdir"
alias v="nvim"
alias cat="bat"
alias cd="z"
alias zrc="${=EDITOR} ~/.zshrc"
alias zshrc="${=EDITOR} ~/.zshrc"
alias ssh_kitty="kitty +kitten ssh"

# npm
alias nd="npm run dev"
alias nb="npm run build"

alias pn="pnpm"
alias pni="pnpm install"
alias pnu="pnpm update"
alias pnd="pnpm dev"
alias pnb="pnpm build"
alias pnt="pnpm test"
alias pnl="pnpm lint"
alias pnr="pnpm cz"

# tmux
alias ta="tmux attach"
alias tl="tmux list-sessions"
alias tn="tmux new -t"
alias tk="tmux kill-session -t"

# git
alias g="git"
alias gs="git status"
alias gd="git diff"
alias ga="git add"
alias gaa="git add --all"
alias gc="git commit"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gpl="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gn="git config user.name"
alias ge="git config user.email"

# lazyworktree, lazygit, workmux
alias lg="lazygit"
alias lw="lazyworktree"
alias wm="workmux"

# yazi
alias y="yazi"

# etc, custom functions
alias cl='claude --dangerously-skip-permissions'
alias tp='tmux_project'
alias tm='tmux_monitor'
alias e="$EDITOR"
