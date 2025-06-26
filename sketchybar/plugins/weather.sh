#!/usr/bin/env bash

# Get weather information using wttr.in
WEATHER="$(curl -s 'wttr.in/Seoul?format=%c%t' 2>/dev/null)"

if [ -z "$WEATHER" ]; then
    # Fallback if no internet connection
    ICON="󰖐"
    LABEL="--"
else
    # Extract icon (first character) and temperature
    ICON="$(echo "${WEATHER:0:1}")"
    TEMP="$(echo "${WEATHER:1}" | sed 's/+//')"
    LABEL="$TEMP"
fi

# Update sketchybar
sketchybar --set "$NAME" icon="$ICON" label="$LABEL"