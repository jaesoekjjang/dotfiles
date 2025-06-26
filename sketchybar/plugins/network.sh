#!/usr/bin/env bash

# Get current network interface
INTERFACE=$(route get default | grep interface | awk '{print $2}')

if [[ -z "$INTERFACE" ]]; then
    # No network connection
    ICON="󰌙"
    LABEL="Offline"
else
    # Check if it's WiFi or Ethernet
    if [[ "$INTERFACE" == en0 ]]; then
        # WiFi interface
        WIFI_NAME=$(networksetup -getairportnetwork en0 | cut -d" " -f4-)
        if [[ "$WIFI_NAME" == *"not associated"* ]]; then
            ICON="󰖪"
            LABEL="No WiFi"
        else
            # Get WiFi signal strength
            SIGNAL=$(airport -I | grep CtlRSSI | awk '{print $2}')
            if [[ -n "$SIGNAL" ]]; then
                if [[ $SIGNAL -gt -50 ]]; then
                    ICON="󰤨"  # Strong signal
                elif [[ $SIGNAL -gt -70 ]]; then
                    ICON="󰤥"  # Medium signal
                else
                    ICON="󰤢"  # Weak signal
                fi
            else
                ICON="󰤨"
            fi
            LABEL="$WIFI_NAME"
            # Truncate long WiFi names
            if [[ ${#LABEL} -gt 12 ]]; then
                LABEL="${LABEL:0:10}..."
            fi
        fi
    else
        # Ethernet or other wired connection
        ICON="󰈀"
        LABEL="Ethernet"
    fi
fi

# Update sketchybar
sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
