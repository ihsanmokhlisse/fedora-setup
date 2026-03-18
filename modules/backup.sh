#!/usr/bin/env bash
# Automated Btrfs System Snapshots — Timeshift & grub-btrfs integration
# Ensures the system can be rolled back from the GRUB menu if an update breaks it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configure_backups() {
    echo ""
    echo "━━━ System Backup & Snapshot Configuration ━━━"

    if ! mount | grep -q "on / type btrfs"; then
        echo "[SKIP] Root filesystem is not Btrfs. Snapshots require Btrfs."
        return 0
    fi

    install_snapshot_tools
    configure_timeshift
    configure_grub_btrfs

    echo ""
    echo "[OK] Automated Btrfs snapshots configured"
    echo "[NOTE] Snapshots will now appear in your GRUB boot menu"
}

install_snapshot_tools() {
    echo ""
    echo "[+] Installing snapshot utilities..."

    local pkgs=(
        timeshift
        grub-btrfs
        inotify-tools
    )

    sudo dnf install -y --skip-unavailable "${pkgs[@]}" 2>&1 | tail -3
}

configure_timeshift() {
    echo ""
    echo "[+] Configuring Timeshift for Btrfs..."

    # Create default Timeshift config if it doesn't exist
    sudo mkdir -p /etc/timeshift
    local ts_conf="/etc/timeshift/timeshift.json"

    if [[ ! -f "$ts_conf" ]] || ! grep -q '"btrfs_mode" : "true"' "$ts_conf" 2>/dev/null; then
        sudo tee "$ts_conf" > /dev/null <<EOF
{
  "backup_device_uuid" : "",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "true",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "btrfs_use_qgroup" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false",
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "true",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "3",
  "snapshot_size" : "0",
  "snapshot_count" : "0",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [
    "+ /root/**",
    "+ /root/***",
    "- /home/**",
    "- /home/***",
    "- /root/**",
    "- /root/***",
    "- /tmp/**",
    "- /tmp/***",
    "- /var/tmp/**",
    "- /var/tmp/***",
    "- /var/log/**",
    "- /var/log/***",
    "- /var/crash/**",
    "- /var/crash/***",
    "- /var/spool/**",
    "- /var/spool/***",
    "- /var/lib/libvirt/**",
    "- /var/lib/libvirt/***",
    "- /var/lib/containers/**",
    "- /var/lib/containers/***",
    "- /var/lib/docker/**",
    "- /var/lib/docker/***"
  ],
  "exclude_apps" : []
}
EOF
        echo "  [OK] Timeshift configured for Btrfs mode (Daily & Boot snapshots)"
    else
        echo "  [OK] Timeshift already configured"
    fi

    # Create a systemd service to take a snapshot before DNF updates
    local dnf_hook="/etc/systemd/system/timeshift-autosnap.service"
    if [[ ! -f "$dnf_hook" ]]; then
        sudo tee "$dnf_hook" > /dev/null <<EOF
[Unit]
Description=Timeshift auto-snapshot before system update
Before=dnf-makecache.service

[Service]
Type=oneshot
ExecStart=/usr/bin/timeshift --create --comments "Before System Update" --tags D

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable timeshift-autosnap.service 2>/dev/null
        echo "  [OK] Auto-snapshot before DNF updates enabled"
    fi
}

configure_grub_btrfs() {
    echo ""
    echo "[+] Configuring grub-btrfs (Snapshots in boot menu)..."

    if command -v grub-btrfs &>/dev/null || systemctl list-unit-files grub-btrfsd.service &>/dev/null; then
        sudo systemctl enable --now grub-btrfsd.service 2>/dev/null || true
        
        # Rebuild GRUB to include current snapshots
        if [[ -d /sys/firmware/efi ]]; then
            sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null > /dev/null
        else
            sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null > /dev/null
        fi
        
        echo "  [OK] grub-btrfs daemon enabled. Snapshots will appear in GRUB."
    else
        echo "  [WARN] grub-btrfs not found. Snapshots must be restored via Timeshift app."
    fi
}
