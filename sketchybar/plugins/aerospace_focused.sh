#!/usr/bin/env bash

source "$CONFIG_DIR/environment"
source "$THEME_DIR/tokyonight"

focused_workspace=$(aerospace list-workspaces --focused)

sketchybar --set "$NAME" \
  label="$focused_workspace" \
  label.font="$ICON_BASE_FONT:Bold:14.0" \
  label.color="$red"
