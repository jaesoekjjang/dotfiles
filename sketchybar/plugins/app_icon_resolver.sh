#!/usr/bin/env bash

# Source environment if available, otherwise set defaults
if [ -f "$CONFIG_DIR/environment" ]; then
    source "$CONFIG_DIR/environment"
fi

# Source icon map
if [ -f "$CONFIG_DIR/helpers/icon_map.sh" ]; then
    source "$CONFIG_DIR/helpers/icon_map.sh"
else
    echo "Warning: icon_map.sh not found at $CONFIG_DIR/helpers/icon_map.sh" >&2
fi

resolve_app_icon() {
    local app_name="$1"
    # sketchybar-app-font를 사용하면 애플리케이션 이름이 바로 아이콘으로 변환됩니다
    # 애플리케이션 이름을 그대로 반환하고, 폰트 설정으로 아이콘 렌더링
    echo "$app_name"
}

get_workspace_app_icons() {
    local workspace=$1
    local apps=($(aerospace list-windows --workspace "$workspace" --format "%{app-name}" | sort | uniq))
    local icons=()
    
    for app in "${apps[@]}"; do
        if [ -n "$app" ] && [ "$app" != "" ]; then
            local icon=$(resolve_app_icon "$app")
            icons+=("$icon")
        fi
    done
    
    echo "${icons[@]}"
}

get_workspace_app_icons_string() {
    local workspace=$1
    local icons=($(get_workspace_app_icons "$workspace"))
    local icons_string=""
    
    for icon in "${icons[@]}"; do
        if [ -n "$icon" ] && [ "$icon" != "" ]; then
            if [ -n "$icons_string" ]; then
                icons_string="$icons_string $icon"
            else
                icons_string="$icon"
            fi
        fi
    done
    
    echo "$icons_string"
}

get_workspace_label() {
    local workspace=$1
    local icons_string=$(get_workspace_app_icons_string "$workspace")
    
    if [ -n "$icons_string" ]; then
        echo "[$workspace] $icons_string"
    else
        echo "[$workspace]"
    fi
}

# Function to get app count for a workspace
get_workspace_app_count() {
    local workspace=$1
    aerospace list-windows --workspace "$workspace" | wc -l | tr -d ' '
}

# Function to check if workspace is empty
is_workspace_empty() {
    local workspace=$1
    local count=$(get_workspace_app_count "$workspace")
    [ "$count" -eq 0 ]
}

# Function to get unique app names in workspace
get_unique_app_names() {
    local workspace=$1
    aerospace list-windows --workspace "$workspace" --format "%{app-name}" | sort | uniq | grep -v '^$'
}

# Debug function to show icon resolution
debug_app_icons() {
    local workspace=$1
    echo "=== App Icons Debug for Workspace $workspace ==="
    local apps=($(get_unique_app_names "$workspace"))
    
    for app in "${apps[@]}"; do
        local icon=$(resolve_app_icon "$app")
        echo "App: '$app' -> Icon: '$icon'"
    done
    
    echo "Icons string: '$(get_workspace_app_icons_string "$workspace")'"
    echo "Full label: '$(get_workspace_label "$workspace")'"
    echo "==============================================="
}
