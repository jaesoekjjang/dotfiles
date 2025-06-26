#!/usr/bin/env bash

# Colors
ACTIVE_COLOR="0xff7dcfff"  # cyan
DIM_COLOR="0xff565f89"     # dimmed

# Get current app from front_app_switched event or fallback to frontmost app
CURRENT_APP="$INFO"
if [[ -z "$CURRENT_APP" ]]; then
    CURRENT_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "")
fi

get_category() {
    local app="$1"
    
    # DEV apps - editors, terminals, dev tools
    if [[ "$app" =~ ^(Code|Cursor|Xcode|.*IDE|.*Storm|Neovim?|.*vim|Emacs|Sublime|Atom|Nova|CotEditor|Zed)$ ]] || \
       [[ "$app" =~ ^(Terminal|终端|ターミナル|iTerm2?|kitty|Alacritty|Hyper|Warp|WezTerm|Tabby|Rio|Ghostty)$ ]] || \
       [[ "$app" =~ ^(Docker|GitHub|Postman)$ ]]; then
        echo "dev"
        return
    fi
    
    # BROWSER apps - all browsers
    if [[ "$app" =~ (Chrome|Safari|Firefox|Arc|Edge|Brave|Opera|Vivaldi|Orion) ]] || \
       [[ "$app" =~ (Chromium|LibreWolf|Mullvad|Tor|qutebrowser|Min|Zen|Yandex) ]] || \
       [[ "$app" =~ (Browser)$ ]]; then
        echo "browser"
        return
    fi
    
    # MUSIC apps - music and audio
    if [[ "$app" =~ ^(Spotify|Music|음악|Musique|Musik|Logic Pro|TIDAL)$ ]] || \
       [[ "$app" =~ ^(YouTube Music|Deezer|Live|Audacity|rekordbox|Plexamp)$ ]]; then
        echo "music"
        return
    fi
    
    # MESSENGER apps - communication and messaging
    if [[ "$app" =~ (Discord|Slack|Telegram|WhatsApp|KakaoTalk|Line|WeChat|Signal|Mattermost) ]] || \
       [[ "$app" =~ (Messenger|Messages|메시지|메신저|카카오톡|라인|텔레그램|매터모스트) ]] || \
       [[ "$app" =~ (Skype|Zoom|Teams|Meet|FaceTime|Element|Matrix|Threema) ]]; then
        echo "messenger"
        return
    fi
    
    # SYSTEM apps - system utilities and settings
    if [[ "$app" =~ ^(System|시스템|Système|Systemeinstellungen)$ ]] || \
       [[ "$app" =~ (Preferences|Settings|설정|Réglages)$ ]] || \
       [[ "$app" =~ ^(Activity Monitor|Finder|Calculator|App Store|Raycast|Alfred|Spotlight)$ ]] || \
       [[ "$app" =~ ^(CleanMyMac|BetterTouchTool|Keyboard Maestro|1Password|Bitwarden|KeePassXC)$ ]]; then
        echo "system"
        return
    fi
    
    # No category found
    echo ""
}

# Determine current category
CURRENT_CATEGORY=$(get_category "$CURRENT_APP")

# Debug logging
echo "Script triggered at $(date)" >> /tmp/sketchybar_debug.log
echo "SENDER: $SENDER" >> /tmp/sketchybar_debug.log
echo "INFO: $INFO" >> /tmp/sketchybar_debug.log
echo "NAME: $NAME" >> /tmp/sketchybar_debug.log
echo "Current app: '$CURRENT_APP'" >> /tmp/sketchybar_debug.log
echo "Category: '$CURRENT_CATEGORY'" >> /tmp/sketchybar_debug.log

# Update individual category items
sketchybar --set cat_dev icon.color="$([[ "$CURRENT_CATEGORY" == "dev" ]] && echo "$ACTIVE_COLOR" || echo "$DIM_COLOR")" \
                 icon.font="$([[ "$CURRENT_CATEGORY" == "dev" ]] && echo "Hack Nerd Font:Bold:17.0" || echo "Hack Nerd Font:Regular:17.0")" \
           --set cat_browser icon.color="$([[ "$CURRENT_CATEGORY" == "browser" ]] && echo "$ACTIVE_COLOR" || echo "$DIM_COLOR")" \
                 icon.font="$([[ "$CURRENT_CATEGORY" == "browser" ]] && echo "Hack Nerd Font:Bold:17.0" || echo "Hack Nerd Font:Regular:17.0")" \
           --set cat_music icon.color="$([[ "$CURRENT_CATEGORY" == "music" ]] && echo "$ACTIVE_COLOR" || echo "$DIM_COLOR")" \
                 icon.font="$([[ "$CURRENT_CATEGORY" == "music" ]] && echo "Hack Nerd Font:Bold:17.0" || echo "Hack Nerd Font:Regular:17.0")" \
           --set cat_messenger icon.color="$([[ "$CURRENT_CATEGORY" == "messenger" ]] && echo "$ACTIVE_COLOR" || echo "$DIM_COLOR")" \
                 icon.font="$([[ "$CURRENT_CATEGORY" == "messenger" ]] && echo "Hack Nerd Font:Bold:17.0" || echo "Hack Nerd Font:Regular:17.0")" \
           --set cat_system icon.color="$([[ "$CURRENT_CATEGORY" == "system" ]] && echo "$ACTIVE_COLOR" || echo "$DIM_COLOR")" \
                 icon.font="$([[ "$CURRENT_CATEGORY" == "system" ]] && echo "Hack Nerd Font:Bold:17.0" || echo "Hack Nerd Font:Regular:17.0")"

echo "Updated colors - dev: $([[ "$CURRENT_CATEGORY" == "dev" ]] && echo "ACTIVE" || echo "DIM"), browser: $([[ "$CURRENT_CATEGORY" == "browser" ]] && echo "ACTIVE" || echo "DIM"), music: $([[ "$CURRENT_CATEGORY" == "music" ]] && echo "ACTIVE" || echo "DIM"), messenger: $([[ "$CURRENT_CATEGORY" == "messenger" ]] && echo "ACTIVE" || echo "DIM"), system: $([[ "$CURRENT_CATEGORY" == "system" ]] && echo "ACTIVE" || echo "DIM")" >> /tmp/sketchybar_debug.log
echo "---" >> /tmp/sketchybar_debug.log
