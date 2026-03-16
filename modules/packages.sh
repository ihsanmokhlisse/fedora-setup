#!/usr/bin/env bash
# Package installation — reads from configs/packages.list

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_packages() {
    echo ""
    echo "━━━ Installing system packages ━━━"

    local pkg_file="${SCRIPT_DIR}/configs/packages.list"

    if [[ ! -f "$pkg_file" ]]; then
        echo "[ERROR] Package list not found: $pkg_file"
        return 1
    fi

    local packages=()
    while IFS= read -r line; do
        line="${line%%#*}"       # strip comments
        line="${line// /}"       # strip spaces
        [[ -z "$line" ]] && continue
        packages+=("$line")
    done < "$pkg_file"

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "[SKIP] No packages to install."
        return 0
    fi

    echo "[+] Installing ${#packages[@]} packages..."

    case "$PKG_MANAGER" in
        dnf)
            sudo dnf install -y --skip-unavailable "${packages[@]}" 2>&1 | \
                tail -5
            ;;
        apt)
            sudo apt update -qq
            sudo apt install -y "${packages[@]}" 2>&1 | tail -5
            ;;
        pacman)
            sudo pacman -Syu --noconfirm "${packages[@]}" 2>&1 | tail -5
            ;;
        *)
            echo "[ERROR] Unsupported package manager: $PKG_MANAGER"
            return 1
            ;;
    esac

    echo "[OK] Package installation complete"
}

install_flatpaks() {
    echo ""
    echo "━━━ Installing Flatpak applications ━━━"

    local flatpak_file="${SCRIPT_DIR}/configs/flatpaks.list"

    if [[ ! -f "$flatpak_file" ]]; then
        echo "[SKIP] Flatpak list not found."
        return 0
    fi

    if ! command -v flatpak &>/dev/null; then
        echo "[SKIP] Flatpak not installed."
        return 0
    fi

    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -z "$line" ]] && continue

        if flatpak info "$line" &>/dev/null; then
            echo "[OK] $line already installed"
        else
            echo "[+] Installing $line..."
            flatpak install -y flathub "$line" 2>&1 | tail -2
        fi
    done < "$flatpak_file"

    echo "[+] Fixing Flatpak permissions (allowing access to themes and fonts)..."
    sudo flatpak override --filesystem=$HOME/.themes 2>/dev/null || true
    sudo flatpak override --filesystem=$HOME/.icons 2>/dev/null || true
    sudo flatpak override --filesystem=$HOME/.local/share/fonts 2>/dev/null || true
    sudo flatpak override --filesystem=xdg-config/gtk-3.0 2>/dev/null || true
    sudo flatpak override --filesystem=xdg-config/gtk-4.0 2>/dev/null || true

    echo "[OK] Flatpak installation complete"
}
