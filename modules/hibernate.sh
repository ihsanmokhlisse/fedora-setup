#!/usr/bin/env bash
# Suspend-then-Hibernate — suspends immediately, hibernates after timeout
# Saves battery when laptop is forgotten in a bag

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configure_hibernate() {
    echo ""
    echo "━━━ Suspend-then-Hibernate ━━━"

    if [[ "$IS_LAPTOP" != true ]]; then
        echo "[SKIP] Not a laptop — suspend-then-hibernate not needed"
        return 0
    fi

    check_swap_for_hibernate
    configure_sleep_mode
    configure_lid_action
    configure_logind

    echo ""
    echo "[OK] Suspend-then-hibernate configured"
}

check_swap_for_hibernate() {
    echo ""
    echo "[+] Checking swap/ZRAM for hibernate support..."

    local swap_total
    swap_total=$(awk '/^SwapTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
    local ram_total
    ram_total=$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)

    if [[ "$swap_total" -lt "$ram_total" ]]; then
        echo "  [WARN] Swap (${swap_total}MB) < RAM (${ram_total}MB)"
        echo "         Full hibernation requires swap >= RAM."
        echo "         With ZRAM-only, suspend-then-hibernate will suspend but may not hibernate."
        echo "         To enable full hibernate, create a swap file:"
        echo "           sudo btrfs filesystem mkswapfile --size ${ram_total}m /swap/swapfile"
        echo "           Add to /etc/fstab and resume= kernel param"
    else
        echo "  [OK] Swap (${swap_total}MB) sufficient for RAM (${ram_total}MB)"
    fi
}

configure_sleep_mode() {
    echo ""
    echo "[+] Configuring suspend-then-hibernate timeout..."

    local sleep_conf="/etc/systemd/sleep.conf.d"
    sudo mkdir -p "$sleep_conf"

    local sleep_file="${sleep_conf}/99-fedoraflow.conf"
    if [[ ! -f "$sleep_file" ]]; then
        sudo tee "$sleep_file" > /dev/null <<'EOF'
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes

# Suspend for 30 minutes, then hibernate to save battery
HibernateDelaySec=1800
SuspendEstimationSec=1800
EOF
        echo "  [OK] Suspend → 30min → Hibernate configured"
    else
        echo "  [OK] Sleep configuration already present"
    fi
}

configure_lid_action() {
    echo ""
    echo "[+] Configuring lid close action..."

    local logind_dir="/etc/systemd/logind.conf.d"
    sudo mkdir -p "$logind_dir"

    local logind_file="${logind_dir}/99-lid-hibernate.conf"
    if [[ ! -f "$logind_file" ]]; then
        sudo tee "$logind_file" > /dev/null <<'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
EOF
        echo "  [OK] Lid close: suspend-then-hibernate on battery, suspend on AC"
    else
        echo "  [OK] Lid action already configured"
    fi
}

configure_logind() {
    echo ""
    echo "[+] Applying logind changes..."

    sudo systemctl restart systemd-logind 2>/dev/null || true
    echo "  [OK] logind restarted with new configuration"

    echo ""
    echo "  Summary:"
    echo "    • Lid close (battery) → Suspend → 30min → Hibernate"
    echo "    • Lid close (AC)      → Suspend only"
    echo "    • Lid close (docked)  → Ignore"
}
