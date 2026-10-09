# Homebrew may live under either prefix. Preserve a working shell before install.
if [[ "$CPUTYPE" == arm64 && -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif (( $+commands[brew] )); then
  eval "$(brew shellenv)"
fi
path=("$HOME/.local/bin" "${path[@]}")
