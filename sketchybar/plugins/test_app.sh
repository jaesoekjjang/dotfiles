#!/usr/bin/env bash

# Test script to debug app name matching
declare -A APP_CATEGORIES=(
    ["Google Chrome"]="browser"
    ["System Settings"]="system"
    ["Ghostty"]="dev"
)

APP_NAME="Google Chrome"
echo "Testing app: '$APP_NAME'"
echo "Keys in array:"
for key in "${!APP_CATEGORIES[@]}"; do
    echo "  '$key'"
done

if [[ -n "${APP_CATEGORIES[$APP_NAME]}" ]]; then
    echo "Found category: ${APP_CATEGORIES[$APP_NAME]}"
else
    echo "NOT FOUND in mapping"
fi