#!/usr/bin/env bash
# System detection — identifies OS, version, desktop environment, GPU, etc.

detect_system() {
    OS_ID="unknown"
    OS_VERSION=""
    OS_NAME=""
    DESKTOP_ENV=""
    GNOME_VER=""
    GPU_VENDOR=""
    ARCH=$(uname -m)
    PKG_MANAGER=""
    IS_WAYLAND=false
    IS_LAPTOP=false

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_ID="${ID}"
        OS_VERSION="${VERSION_ID}"
        OS_NAME="${PRETTY_NAME}"
    fi

    if command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v apt &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    elif command -v zypper &>/dev/null; then
        PKG_MANAGER="zypper"
    fi

    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
    elif [[ -n "$DESKTOP_SESSION" ]]; then
        DESKTOP_ENV="$DESKTOP_SESSION"
    fi

    if command -v gnome-shell &>/dev/null; then
        GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*')
        GNOME_MAJOR=$(echo "$GNOME_VER" | cut -d. -f1)
    fi

    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        IS_WAYLAND=true
    fi

    local lspci_output
    lspci_output=$(lspci 2>/dev/null || true)
    if echo "$lspci_output" | grep -qi "nvidia"; then
        GPU_VENDOR="nvidia"
    elif echo "$lspci_output" | grep -qi "amd.*radeon\|amd.*display\|ati"; then
        GPU_VENDOR="amd"
    elif echo "$lspci_output" | grep -qi "intel.*graphics\|intel.*display"; then
        GPU_VENDOR="intel"
    fi

    if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
        IS_LAPTOP=true
    fi

    export OS_ID OS_VERSION OS_NAME DESKTOP_ENV GNOME_VER GNOME_MAJOR
    export GPU_VENDOR ARCH PKG_MANAGER IS_WAYLAND IS_LAPTOP
}

print_system_info() {
    echo "┌──────────────────────────────────────────────┐"
    echo "│           System Detection Results           │"
    echo "├──────────────────────────────────────────────┤"
    printf "│  %-12s : %-28s │\n" "OS" "$OS_NAME"
    printf "│  %-12s : %-28s │\n" "Version" "$OS_VERSION"
    printf "│  %-12s : %-28s │\n" "Arch" "$ARCH"
    printf "│  %-12s : %-28s │\n" "Desktop" "$DESKTOP_ENV"
    printf "│  %-12s : %-28s │\n" "GNOME" "${GNOME_VER:-N/A}"
    printf "│  %-12s : %-28s │\n" "GPU" "${GPU_VENDOR:-unknown}"
    printf "│  %-12s : %-28s │\n" "Wayland" "$IS_WAYLAND"
    printf "│  %-12s : %-28s │\n" "Laptop" "$IS_LAPTOP"
    printf "│  %-12s : %-28s │\n" "Pkg Manager" "$PKG_MANAGER"
    echo "└──────────────────────────────────────────────┘"
}

require_fedora() {
    if [[ "$OS_ID" != "fedora" ]]; then
        echo "[ERROR] This script is designed for Fedora Linux."
        echo "        Detected: $OS_NAME"
        echo "        Some modules may still work. Continue? [y/N]"
        read -r answer
        [[ "$answer" =~ ^[Yy] ]] || exit 1
    fi
}

require_gnome() {
    if ! echo "$DESKTOP_ENV" | grep -qi "gnome"; then
        echo "[WARN] GNOME desktop not detected (found: $DESKTOP_ENV)."
        echo "       GNOME-specific modules will be skipped."
        return 1
    fi
    return 0
}

require_min_gnome_version() {
    local required="$1"
    if [[ -z "$GNOME_MAJOR" ]] || [[ "$GNOME_MAJOR" -lt "$required" ]]; then
        echo "[WARN] GNOME $required+ required, found ${GNOME_VER:-none}."
        return 1
    fi
    return 0
}
