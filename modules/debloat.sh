#!/usr/bin/env bash
# Debloat and Privacy — Removes telemetry and non-essential default apps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_debloat() {
    echo ""
    echo -e "${BOLD}━━━ Debloating & Privacy ━━━${NC}"

    remove_bloatware
    disable_telemetry

    echo ""
    echo "[OK] System debloated and telemetry disabled"
}

remove_bloatware() {
    echo ""
    echo "[+] Removing non-essential default GNOME apps..."

    local bloat=(
        gnome-tour
        gnome-contacts
        gnome-weather
        gnome-maps
        yelp
        gnome-clocks
        gnome-software-telemetry
    )

    sudo dnf remove -y "${bloat[@]}" 2>&1 | tail -3
    echo "  [OK] Removed GNOME Tour, Contacts, Weather, Maps, Yelp, Clocks"
}

disable_telemetry() {
    echo ""
    echo "[+] Disabling system telemetry..."

    # Disable ABRT (Automatic Bug Reporting Tool)
    if systemctl is-enabled abrt-ccpp.service &>/dev/null; then
        sudo systemctl disable --now abrt-ccpp.service 2>/dev/null
        sudo systemctl disable --now abrt-oops.service 2>/dev/null
        sudo systemctl disable --now abrt-xorg.service 2>/dev/null
        sudo systemctl disable --now abrt-vmcore.service 2>/dev/null
        sudo systemctl mask abrt-ccpp.service 2>/dev/null
        echo "  [OK] ABRT (crash reporting telemetry) disabled"
    fi

    # Disable GNOME Software Telemetry
    gsettings set org.gnome.software download-updates false 2>/dev/null || true
    echo "  [OK] GNOME Software telemetry disabled"
}
