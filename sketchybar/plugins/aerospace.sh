#!/usr/bin/env bash

source "$CONFIG_DIR/environment"
source "$THEME_DIR/tokyonight"
source "/Users/mac/Library/Mobile Documents/com~apple~CloudDocs/Dotfiles/sketchybar/helpers/icon_map.sh"

# Get the current focused workspace
FOCUSED_WORKSPACE=${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}

# Function to get app icon using existing icon map
get_app_icon() {
    local app_name="$1"
    __icon_map "$app_name"
    echo "$icon_result"
}

# Function to get apps in a workspace  
get_workspace_apps() {
    local workspace="$1"
    aerospace list-windows --workspace "$workspace" --format '%{app-name}' 2>/dev/null | head -3
}

# Function to check if workspace is visible/has apps
workspace_has_apps() {
    local workspace="$1"
    local app_count=$(aerospace list-windows --workspace "$workspace" 2>/dev/null | wc -l)
    [[ $app_count -gt 0 ]]
}

# Function to update workspace item
update_workspace_item() {
    local workspace="$1"
    local item_name="aerospace.$workspace"
    
    local has_apps=true
    
    local icon_color="$red"
    local border_color="$white"
    local border_width=0
    
    # Style for focused workspace
    if [[ "$workspace" == "$FOCUSED_WORKSPACE" ]]; then
        icon=""
        label_color="$white"
        border_color="$red"
        border_width=1
        bg_drawing="on"
      else
        icon=""
        label_color="$gray"
        bg_drawing="off"
    fi
    
    # Build app icons string (max 3 apps, only for workspaces with apps)
    local app_icons=""
    if [[ "$has_apps" == true ]]; then
        local apps=$(get_workspace_apps "$workspace")
        local count=0
        while IFS= read -r app && [[ $count -lt 3 ]]; do
            if [[ -n "$app" ]]; then
                local app_icon=$(get_app_icon "$app")
                if [[ -n "$app_icon" ]]; then
                    app_icons+=" $app_icon"
                    ((count++))
                fi
            fi
        done <<< "$apps"
    fi
    
    # Update the item
    sketchybar --set "$item_name" \
               icon="$icon" \
               icon.color="$icon_color" \
               background.border_color="$border_color" \
               background.border_width="$border_width" \
               background.drawing="$bg_drawing" \
               background.color="$background_color" \
               label="$app_icons" \
               label.font="sketchybar-app-font:Regular:14.0" \
               label.color="$label_color"

}

# Update all workspace items
IFS=$'\n' WORKSPACES=($(aerospace list-workspaces --monitor all --empty no))

for workspace in "${WORKSPACES[@]}"; do
  echo "Updating workspace: '$workspace'" >&2
  update_workspace_item "$workspace"
done
