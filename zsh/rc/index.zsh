#!/usr/bin/env zsh

ZSH_CONFIG_DIR="${0:A:h}"

source "$ZSH_CONFIG_DIR/env.zsh"
source "$ZSH_CONFIG_DIR/alias.zsh"
source "$ZSH_CONFIG_DIR/bindkey.zsh"
source "$ZSH_CONFIG_DIR/workmux.zsh"

[[ -f ~/.secrets.zsh ]] && source ~/.secrets.zsh
