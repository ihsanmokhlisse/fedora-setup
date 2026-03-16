#!/usr/bin/env bash
# System updates — DNF, Flatpak, firmware, and automatic update configuration
# Designed to keep the system secure and up-to-date with minimal user effort

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configure_updates() {
    echo ""
    echo "━━━ System Updates & Auto-Update Configuration ━━━"

    run_system_update
    run_firmware_update
    run_flatpak_update
    setup_auto_updates

    echo ""
    echo "[OK] System fully updated and auto-updates configured"
}

run_system_update() {
    echo ""
    echo "[+] Updating system packages..."

    case "$PKG_MANAGER" in
        dnf)
            sudo dnf upgrade --refresh -y 2>&1 | tail -5
            ;;
        apt)
            sudo apt update && sudo apt upgrade -y 2>&1 | tail -5
            ;;
        pacman)
            sudo pacman -Syu --noconfirm 2>&1 | tail -5
            ;;
        *)
            echo "  [SKIP] Unsupported package manager: $PKG_MANAGER"
            return 0
            ;;
    esac

    echo "  [OK] System packages updated"
}

run_firmware_update() {
    echo ""
    echo "[+] Checking firmware updates..."

    if ! command -v fwupdmgr &>/dev/null; then
        echo "  [+] Installing fwupd..."
        sudo dnf install -y fwupd 2>&1 | tail -2
    fi

    echo "  [+] Refreshing firmware metadata..."
    fwupdmgr get-devices 2>/dev/null || true
    fwupdmgr refresh --force 2>/dev/null || true

    echo "  [+] Checking for available firmware updates..."
    local fw_updates
    fw_updates=$(fwupdmgr get-updates 2>&1)

    if echo "$fw_updates" | grep -q "No updates available"; then
        echo "  [OK] All firmware is up to date"
    elif echo "$fw_updates" | grep -q "Devices with no available"; then
        echo "  [OK] No firmware updates available"
    else
        echo "  [+] Firmware updates available:"
        echo "$fw_updates" | grep -E "^  |→" | head -10
        echo ""
        echo "  [+] Installing firmware updates..."
        fwupdmgr update -y 2>&1 | tail -5
        echo "  [OK] Firmware updates applied (reboot may be required)"
    fi
}

run_flatpak_update() {
    echo ""
    echo "[+] Updating Flatpak applications..."

    if ! command -v flatpak &>/dev/null; then
        echo "  [SKIP] Flatpak not installed"
        return 0
    fi

    flatpak update -y 2>&1 | tail -5
    echo "  [OK] Flatpak applications updated"
}

setup_auto_updates() {
    echo ""
    echo "[+] Configuring automatic updates..."

    configure_dnf_automatic
    configure_flatpak_auto_update
    configure_fwupd_auto_update

    echo "  [OK] Auto-updates configured"
}

configure_dnf_automatic() {
    echo ""
    echo "  [+] Setting up DNF automatic security updates..."

    if [[ "$PKG_MANAGER" != "dnf" ]]; then
        return 0
    fi

    # dnf5 uses a different plugin
    if command -v dnf5 &>/dev/null; then
        if ! rpm -q dnf5-plugin-automatic &>/dev/null; then
            sudo dnf install -y dnf5-plugin-automatic 2>&1 | tail -2
        fi
    else
        if ! rpm -q dnf-automatic &>/dev/null; then
            sudo dnf install -y dnf-automatic 2>&1 | tail -2
        fi
    fi

    local auto_conf="/etc/dnf/automatic.conf"
    if [[ -f "$auto_conf" ]]; then
        # Download and apply security updates automatically
        sudo sed -i 's/^upgrade_type.*/upgrade_type = security/' "$auto_conf" 2>/dev/null
        sudo sed -i 's/^apply_updates.*/apply_updates = yes/' "$auto_conf" 2>/dev/null
        sudo sed -i 's/^download_updates.*/download_updates = yes/' "$auto_conf" 2>/dev/null

        echo "    [OK] DNF automatic: security updates auto-applied"
    fi

    sudo systemctl enable --now dnf-automatic.timer 2>/dev/null || \
    sudo systemctl enable --now dnf5-automatic.timer 2>/dev/null || true

    echo "    [OK] DNF automatic timer enabled"
}

configure_flatpak_auto_update() {
    echo ""
    echo "  [+] Setting up Flatpak auto-updates..."

    if ! command -v flatpak &>/dev/null; then
        return 0
    fi

    local timer_dir="$HOME/.config/systemd/user"
    mkdir -p "$timer_dir"

    if [[ ! -f "${timer_dir}/flatpak-update.service" ]]; then
        cat > "${timer_dir}/flatpak-update.service" <<'EOF'
[Unit]
Description=Flatpak Auto Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update -y --noninteractive
EOF

        cat > "${timer_dir}/flatpak-update.timer" <<'EOF'
[Unit]
Description=Flatpak Auto Update Timer

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

        systemctl --user daemon-reload
        systemctl --user enable --now flatpak-update.timer 2>/dev/null
        echo "    [OK] Flatpak daily auto-update enabled"
    else
        echo "    [OK] Flatpak auto-update already configured"
    fi
}

configure_fwupd_auto_update() {
    echo ""
    echo "  [+] Enabling automatic firmware update checks..."

    if command -v fwupdmgr &>/dev/null; then
        sudo systemctl enable --now fwupd-refresh.timer 2>/dev/null || true
        echo "    [OK] Firmware update checks enabled (weekly)"
    fi
}
