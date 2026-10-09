# system, core apps
(( $+commands[eza] )) && alias ls="eza"
alias rm="rm -i"
alias cp="cp -i"
alias md="mkdir"
alias v="nvim"
alias cat="bat"
alias cd="z"
alias zrc="${=EDITOR} ~/.zshrc"
alias sz="source ~/.zshrc"

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

# k8s
alias k="kubectl"

# awk
alias awk="gawk"

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
alias gl="git log --oneline --graph --decorate"
alias gr="git restore"
alias grs="git restore --staged"
alias gn="git config user.name"
alias ge="git config user.email"

# lazygit
alias lg="lazygit"

# yazi
alias y="yazi"

# etc, custom functions
alias e="$EDITOR"
alias ex="exercism"
