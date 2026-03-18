#!/usr/bin/env bash
# Wayland Screen Sharing Fix — xdg-desktop-portal + PipeWire integration
# Fixes black screen when sharing in Firefox, Chrome, Teams, Zoom, Discord

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fix_screen_sharing() {
    echo ""
    echo "━━━ Wayland Screen Sharing Fix ━━━"

    install_portal_packages
    configure_firefox_portal
    configure_chromium_portal
    fix_portal_environment
    restart_portal_services

    echo ""
    echo "[OK] Wayland screen sharing configured"
}

install_portal_packages() {
    echo ""
    echo "[+] Installing xdg-desktop-portal stack..."

    local packages=(
        xdg-desktop-portal
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
        pipewire
        pipewire-utils
    )

    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null 2>&1; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        sudo dnf install -y "${to_install[@]}" 2>&1 | tail -3
        echo "  [OK] Portal packages installed"
    else
        echo "  [OK] Portal packages already present"
    fi
}

configure_firefox_portal() {
    echo ""
    echo "[+] Configuring Firefox for native Wayland screen sharing..."

    local firefox_profiles_dir="$HOME/.mozilla/firefox"
    if [[ ! -d "$firefox_profiles_dir" ]]; then
        echo "  [SKIP] Firefox profile directory not found"
        return 0
    fi

    while IFS= read -r profile_dir; do
        local user_js="${profile_dir}/user.js"
        if ! grep -q "widget.use-xdg-desktop-portal.file-picker" "$user_js" 2>/dev/null; then
            cat >> "$user_js" <<'EOF'

// FedoraFlow: Enable native portal integration for screen sharing
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
user_pref("widget.use-xdg-desktop-portal.mime-handler", 1);
user_pref("widget.use-xdg-desktop-portal.settings", 1);
user_pref("widget.use-xdg-desktop-portal.location", 1);
user_pref("widget.use-xdg-desktop-portal.open-uri", 1);
user_pref("media.webrtc.camera.allow-pipewire", true);
EOF
            echo "  [OK] Portal integration added to $(basename "$profile_dir")"
        fi
    done < <(find "$firefox_profiles_dir" -maxdepth 1 -name "*.default*" -type d 2>/dev/null)

    local profile_env="/etc/profile.d/firefox-portal.sh"
    if [[ ! -f "$profile_env" ]]; then
        sudo tee "$profile_env" > /dev/null <<'EOF'
export GTK_USE_PORTAL=1
EOF
        echo "  [OK] GTK_USE_PORTAL=1 set system-wide"
    fi
}

configure_chromium_portal() {
    echo ""
    echo "[+] Ensuring Chromium-based browsers use PipeWire for screen capture..."

    for browser in "chrome" "chromium" "brave"; do
        local flags_file="$HOME/.config/${browser}-flags.conf"
        if [[ -f "$flags_file" ]]; then
            if ! grep -q "WebRTCPipeWireCapturer" "$flags_file" 2>/dev/null; then
                echo "--enable-features=WebRTCPipeWireCapturer" >> "$flags_file"
                echo "  [OK] PipeWire screen capture enabled for $browser"
            else
                echo "  [OK] $browser already has PipeWire capture flag"
            fi
        fi
    done
}

fix_portal_environment() {
    echo ""
    echo "[+] Fixing portal environment variables..."

    local env_file="$HOME/.config/environment.d/50-portal.conf"
    mkdir -p "$HOME/.config/environment.d"

    if [[ ! -f "$env_file" ]]; then
        cat > "$env_file" <<'EOF'
XDG_CURRENT_DESKTOP=GNOME
GTK_USE_PORTAL=1
EOF
        echo "  [OK] Portal environment variables set for user session"
    else
        echo "  [OK] Portal environment already configured"
    fi
}

restart_portal_services() {
    echo ""
    echo "[+] Restarting portal services..."

    systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal-gnome.service 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal-gtk.service 2>/dev/null || true

    if systemctl --user is-active xdg-desktop-portal.service &>/dev/null; then
        echo "  [OK] xdg-desktop-portal is running"
    else
        echo "  [WARN] xdg-desktop-portal failed to start — may need a reboot"
    fi
}
