#!/usr/bin/env bash
# Theme installation and configuration — GTK themes, icon packs, cursors, fonts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_theme_dependencies() {
    echo ""
    echo "━━━ Installing Theme Dependencies ━━━"

    if [[ "$PKG_MANAGER" != "dnf" ]]; then
        echo "[SKIP] DNF not available"
        return 0
    fi

    local pkgs=(
        gnome-tweaks
        adwaita-cursor-theme
        adwaita-icon-theme
        adwaita-icon-theme-legacy
        adwaita-mono-fonts
        adwaita-sans-fonts
        adobe-source-code-pro-fonts
        aajohan-comfortaa-fonts
    )

    sudo dnf install -y --skip-unavailable "${pkgs[@]}" 2>&1 | tail -3
}

apply_theme() {
    echo ""
    echo "━━━ Applying Theme Configuration ━━━"

    if ! require_gnome; then
        return 0
    fi

    echo "[+] Setting GTK theme..."
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'

    echo "[+] Setting icon theme..."
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'

    echo "[+] Setting cursor theme..."
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'

    echo "[+] Setting window manager theme..."
    gsettings set org.gnome.desktop.wm.preferences theme 'Adwaita'

    echo "[+] Setting color scheme..."
    gsettings set org.gnome.desktop.interface color-scheme 'default'

    echo "[+] Setting fonts..."
    gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'
    gsettings set org.gnome.desktop.interface document-font-name 'Adwaita Sans 12'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Adwaita Mono 11'
    gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Adwaita Sans Bold 11'

    echo "[+] Setting font rendering..."
    gsettings set org.gnome.desktop.interface font-hinting 'medium'
    gsettings set org.gnome.desktop.interface text-scaling-factor 0.94

    echo "[+] Enabling animations..."
    gsettings set org.gnome.desktop.interface enable-animations true

    echo "[OK] Theme applied"
}

install_extra_themes() {
    echo ""
    echo "[+] Installing popular community themes (optional)..."

    if [[ "$PKG_MANAGER" != "dnf" ]]; then
        return 0
    fi

    local optional_themes=(
        papirus-icon-theme
        breeze-cursor-theme
    )

    for pkg in "${optional_themes[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            echo "  [OK] $pkg already installed"
        else
            echo "  [+] Installing $pkg..."
            sudo dnf install -y --skip-unavailable "$pkg" 2>/dev/null | tail -1
        fi
    done
}

setup_themes() {
    install_theme_dependencies
    apply_theme
    install_extra_themes
}
