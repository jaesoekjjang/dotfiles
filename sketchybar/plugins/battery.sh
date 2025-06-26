#!/bin/sh

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[0-9]|100) ICON="󱟢" ;;
  [6-8][0-9]) 
    if [[ "${CHARGING}" != "" ]]; then
      ICON="󱊦" 
    else
      ICON="󱊣"
    fi
  ;;
  [3-5][0-9]) 
    if [[ "${CHARGING}" != "" ]]; then
      ICON="󱊥"
    else
      ICON="󱊢"
    fi
  ;;
  [1-2][0-9]) 
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
