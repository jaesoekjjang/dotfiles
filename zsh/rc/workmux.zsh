alias w='workspace'
alias wt='tuios-trial'
if [[ -n "${TUIOS_SESSION:-}" ]]; then
  nvim() { tuios-trial app nvim "$@"; }
fi
if (( $+commands[workmux] )); then
  eval "$(workmux completions zsh)"
fi
