#!/usr/bin/env bash

# Get current date and time
DATE="$(date '+%m/%d')"
TIME="$(date '+%H:%M')"
WEEKDAY="$(date '+%a')"

# Calendar icon
ICON="󰃭"

# Format: Icon Day Date Time
LABEL="$WEEKDAY $DATE $TIME"

# Update sketchybar
sketchybar --set "$NAME" icon="$ICON" label="$LABEL"