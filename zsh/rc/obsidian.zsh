local OBSIDIAN_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"

obs() {
  cd "$OBSIDIAN_VAULT" && nvim .
}
