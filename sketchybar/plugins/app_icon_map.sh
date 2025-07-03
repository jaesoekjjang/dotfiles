#!/usr/bin/env bash

# Convert application names to sketchybar-app-font icons
# This maps app names directly to their corresponding unicode icons
function get_app_icon() {
    case "$1" in
        "kitty")
            echo "󰄛"  # kitty icon
            ;;
        "Google Chrome" | "Chromium")
            echo "󰊯"  # chrome icon
            ;;
        "Safari")
            echo "󰀸"  # safari icon
            ;;
        "Claude")
            echo "󰭻"  # AI/claude icon
            ;;
        "Obsidian")
            echo "󱉽"  # obsidian icon
            ;;
        "Todoist")
            echo "󰄬"  # todo icon
            ;;
        "카카오톡" | "KakaoTalk")
            echo "󰭹"  # chat icon
            ;;
        "Mattermost")
            echo "󰍩"  # mattermost icon
            ;;
        "Finder" | "访达")
            echo "󰀶"  # finder icon
            ;;
        "시스템 설정" | "System Preferences" | "System Settings")
            echo "󰒓"  # settings icon
            ;;
        "Terminal" | "터미널")
            echo "󰆍"  # terminal icon
            ;;
        "Discord")
            echo "󰙯"  # discord icon
            ;;
        "Code" | "Visual Studio Code")
            echo "󰨞"  # vscode icon
            ;;
        "Figma")
            echo "󰣘"  # figma icon
            ;;
        "Slack")
            echo "󰒱"  # slack icon
            ;;
        "Spotify")
            echo "󰓇"  # spotify icon
            ;;
        "Neovim" | "nvim")
            echo "󰕷"  # neovim icon
            ;;
        "Firefox")
            echo "󰈸"  # firefox icon
            ;;
        "Notes" | "메모" | "备忘录")
            echo "󰂺"  # notes icon
            ;;
        "Mail" | "메일" | "邮件")
            echo "󰇰"  # mail icon
            ;;
        "Calendar" | "캘린더" | "日历")
            echo "󰃭"  # calendar icon
            ;;
        "Photos" | "사진" | "照片")
            echo "󰉏"  # photos icon
            ;;
        "Music" | "음악" | "音乐")
            echo "󰎆"  # music icon
            ;;
        "Calculator" | "계산기" | "计算器")
            echo "󰃬"  # calculator icon
            ;;
        "Docker")
            echo "󰡨"  # docker icon
            ;;
        "Notion")
            echo "󰈙"  # notion icon
            ;;
        "Telegram")
            echo "󰔧"  # telegram icon
            ;;
        "WhatsApp")
            echo "󰖭"  # whatsapp icon
            ;;
        "Zoom")
            echo "󰍫"  # zoom icon
            ;;
        "Microsoft Teams")
            echo "󰊻"  # teams icon
            ;;
        "Xcode")
            echo "󰀵"  # xcode icon
            ;;
        "Android Studio")
            echo "󰀲"  # android studio icon
            ;;
        "Postman")
            echo "󰛵"  # postman icon
            ;;
        "TablePlus")
            echo "󰆼"  # database icon
            ;;
        "Ghostty")
            echo "󰆍"  # terminal icon (fallback for ghostty)
            ;;
        *)
            echo "󰀶"  # default app icon
            ;;
    esac
}

# Alternative function name for consistency
function resolve_app_icon() {
    get_app_icon "$1"
}