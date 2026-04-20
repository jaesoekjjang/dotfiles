#!/usr/bin/env zsh

ZSH_CONFIG_DIR="${0:A:h}"

source "$ZSH_CONFIG_DIR/env.zsh"
source "$ZSH_CONFIG_DIR/alias.zsh"
source "$ZSH_CONFIG_DIR/search.zsh"
source "$ZSH_CONFIG_DIR/bindkey.zsh"
source "$ZSH_CONFIG_DIR/tmux.zsh"
source "$ZSH_CONFIG_DIR/workmux.zsh"
source "$ZSH_CONFIG_DIR/obsidian.zsh"

[[ -f ~/.secrets.zsh ]] && source ~/.secrets.zsh
