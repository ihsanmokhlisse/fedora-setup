#!/usr/bin/env bash
# GNOME desktop configuration — dconf settings, login screen, avatar, video wallpaper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

apply_gnome_settings() {
    echo ""
    echo "━━━ Applying GNOME Settings ━━━"

    if ! require_gnome; then
        return 0
    fi

    local settings_file="${SCRIPT_DIR}/configs/dconf-settings.ini"

    if [[ -f "$settings_file" ]]; then
        echo "[+] Loading dconf settings..."
        dconf load / < "$settings_file"
        echo "[OK] dconf settings applied"
    else
        echo "[WARN] Settings file not found, applying defaults..."
    fi

    echo "[+] Preserving current keyboard layout..."
    gsettings set org.gnome.desktop.input-sources show-all-sources true

    echo "[+] Setting favorite apps (only apps that are installed)..."
    local favorites=()
    local candidate_apps=(
        "org.mozilla.firefox.desktop"
        "org.gnome.Calendar.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Software.desktop"
        "org.gnome.TextEditor.desktop"
        "org.gnome.Calculator.desktop"
    )
    for app in "${candidate_apps[@]}"; do
        if [[ -f "/usr/share/applications/${app}" ]] || \
           [[ -f "/var/lib/flatpak/exports/share/applications/${app}" ]] || \
           [[ -f "$HOME/.local/share/applications/${app}" ]]; then
            favorites+=("'${app}'")
        fi
    done
    if [[ ${#favorites[@]} -gt 0 ]]; then
        local fav_str
        fav_str=$(IFS=,; echo "[${favorites[*]}]")
        gsettings set org.gnome.shell favorite-apps "$fav_str"
    fi

    echo "[+] Setting idle timeout (15 min)..."
    gsettings set org.gnome.desktop.session idle-delay 900

    echo "[+] Enabling edge tiling..."
    gsettings set org.gnome.mutter edge-tiling true

    echo "[+] Setting Super+L to lock screen..."
    gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>l']"

    configure_user_avatar
    configure_gdm_login_screen
    configure_video_wallpaper

    echo "[OK] GNOME settings applied"
}

configure_user_avatar() {
    echo ""
    echo "[+] Configuring user avatar..."

    local avatar_path="$HOME/.face"
    local accountsservice_dir="/var/lib/AccountsService/icons"
    local current_user
    current_user=$(whoami)

    if [[ -f "$avatar_path" ]]; then
        echo "  [OK] User avatar already set (~/.face)"

        if [[ -d "$accountsservice_dir" ]]; then
            if [[ ! -f "${accountsservice_dir}/${current_user}" ]] || \
               ! cmp -s "$avatar_path" "${accountsservice_dir}/${current_user}" 2>/dev/null; then
                sudo cp "$avatar_path" "${accountsservice_dir}/${current_user}" 2>/dev/null
                echo "  [OK] Avatar synced to AccountsService (login screen)"
            fi
        fi
    else
        echo "  [!] No user avatar found."
        echo "      To set your avatar, place an image at: ~/.face"
        echo "      Or use GNOME Settings > Users to set your profile picture."
        echo "      Recommended: 512x512 PNG or JPEG"
    fi

    local qs_avatar_dir="$HOME/.local/share/gnome-shell/extensions/quick-settings-avatar@d-go"
    if [[ -d "$qs_avatar_dir" ]]; then
        echo "  [OK] Quick Settings Avatar extension installed — avatar shown in quick settings"
    fi
}

configure_gdm_login_screen() {
    echo ""
    echo "[+] Configuring login screen (GDM)..."

    if flatpak info io.github.realmazharhussain.GdmSettings &>/dev/null; then
        echo "  [OK] GDM Settings app installed"
        echo "      Open 'Login Screen Settings' to customize:"
        echo "      - Background image"
        echo "      - Theme (dark/light)"
        echo "      - Top bar tweaks"
        echo "      - User list visibility"
    else
        echo "  [!] GDM Settings not installed."
        echo "      It will be installed with Flatpak apps (option 5)."
        echo "      Allows you to set a custom login screen background."
    fi

    local current_bg
    current_bg=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")
    if [[ -n "$current_bg" ]] && [[ "$current_bg" != "''" ]]; then
        local bg_file="${current_bg#file://}"
        if [[ -f "$bg_file" ]]; then
            echo "  [+] Syncing current desktop wallpaper to GDM login screen..."
            sudo cp "$bg_file" /usr/share/backgrounds/gdm-custom-bg.jpg 2>/dev/null || true

            local gdm_dconf="/etc/dconf/db/gdm.d/99-login-screen"
            sudo mkdir -p /etc/dconf/db/gdm.d/ 2>/dev/null
            sudo tee "$gdm_dconf" > /dev/null 2>&1 <<EOF
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/gdm-custom-bg.jpg'
picture-options='zoom'

[org/gnome/login-screen]
logo=''
EOF
            sudo dconf update 2>/dev/null
            echo "  [OK] Login screen wallpaper synced to desktop background"
        fi
    fi
}

configure_video_wallpaper() {
    echo ""
    echo "[+] Video wallpaper support..."

    if ! flatpak info io.github.jeffshee.Hidamari &>/dev/null; then
        echo "  [!] Hidamari not installed."
        echo "      It will be installed with Flatpak apps (option 5)."
        echo "      Allows you to use videos as desktop wallpapers."
        return 0
    fi

    echo "  [OK] Hidamari installed"

    flatpak override --user --filesystem=home:ro io.github.jeffshee.Hidamari 2>/dev/null

    local wallpaper_dir="$HOME/Videos/Wallpapers"
    local video_count
    video_count=$(find "$wallpaper_dir" \( -name "*.mp4" -o -name "*.webm" \) 2>/dev/null | wc -l)

    if [[ "$video_count" -eq 0 ]]; then
        echo "  [!] No video wallpapers found in ~/Videos/Wallpapers/"
        echo "      Place .mp4 or .webm loop files there, then open Hidamari to select one."
    fi

    local hidamari_config="$HOME/.var/app/io.github.jeffshee.Hidamari/config/hidamari/config.json"
    if [[ -f "$hidamari_config" ]]; then
        local first_video
        first_video=$(find "$wallpaper_dir" \( -name "*-loop.mp4" -o -name "*.mp4" \) 2>/dev/null | head -1)
        if [[ -n "$first_video" ]]; then
            local monitor_name
            monitor_name=$(xrandr --query 2>/dev/null | grep " connected" | head -1 | awk '{print $1}')
            [[ -z "$monitor_name" ]] && monitor_name="eDP-1"

            cat > "$hidamari_config" <<HIEOF
{
   "version": 4,
   "mode": "MODE_VIDEO",
   "data_source": {
      "${monitor_name}": "${first_video}",
      "Default": "${first_video}"
   },
   "is_mute": true,
   "audio_volume": 0,
   "is_static_wallpaper": true,
   "static_wallpaper_blur_radius": 5,
   "is_pause_when_maximized": true,
   "is_mute_when_maximized": true,
   "fade_duration_sec": 1.5,
   "fade_interval": 0.1,
   "is_show_systray": true,
   "is_first_time": false
}
HIEOF
            echo "  [OK] Hidamari configured with: $(basename "$first_video")"
            echo "      Open Hidamari to switch videos from ~/Videos/Wallpapers/"
        fi
    fi

    echo ""
    echo "  [NOTE] Video backgrounds on the lock/login screen:"
    echo "         GNOME does not support video on lock screen or GDM."
    echo "         Lock screen uses a static image (synced from desktop or Bing)."
    echo "         Desktop CAN use video wallpapers via Hidamari."
}

configure_lockscreen_wallpaper_sync() {
    echo ""
    echo "[+] Configuring lock screen wallpaper sync..."

    local current_bg
    current_bg=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")

    if [[ -n "$current_bg" ]] && [[ "$current_bg" != "''" ]]; then
        gsettings set org.gnome.desktop.screensaver picture-uri "$current_bg"
        echo "[OK] Lock screen wallpaper synced to desktop"
    fi

    local bing_schema_dir="$HOME/.local/share/gnome-shell/extensions/BingWallpaper@ineffable-gmail.com/schemas"
    if [[ -d "$bing_schema_dir" ]]; then
        GSETTINGS_SCHEMA_DIR="$bing_schema_dir" \
            gsettings set org.gnome.shell.extensions.bingwallpaper set-lock-screen true 2>/dev/null && \
            echo "[OK] BingWallpaper lock screen auto-sync enabled"
    fi
}
