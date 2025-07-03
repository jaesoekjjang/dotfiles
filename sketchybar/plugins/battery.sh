#!/bin/sh

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[5-9]|100) ICON="󱟢" ;;
  [8-9][0-9]) 
    if [[ "${CHARGING}" != "" ]]; then
      ICON="󱊦" 
    else
      ICON="󱊣"
    fi
  ;;
  [5-7][0-9]) 
    if [[ "${CHARGING}" != "" ]]; then
      ICON="󱊥"
    else
      ICON="󱊢"
    fi
  ;;
  [2-4][0-9]) 
    if [[ "${CHARGING}" != "" ]]; then
      ICON="󱊤"
    else
      ICON="󱊡"
    fi
  ;;
  *) 
    if [[ "${CHARGING}" != "" ]]; then
      ICON="󰢟"
    else
      ICON="󰂎"
    fi
esac

sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%"
