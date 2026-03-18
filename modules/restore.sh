#!/usr/bin/env bash
# System restore — Reverts performance, power, and security optimizations
# Useful if the system experiences hardware incompatibility

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

restore_system() {
    echo ""
    echo -e "${BOLD}━━━ System Restore / Rollback ━━━${NC}"
    echo "This will remove custom power, performance, and security configurations"
    echo "and revert the system closer to Fedora defaults."
    echo ""
    
    read -rp "Are you sure you want to proceed? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        return 0
    fi

    echo ""
    echo "[+] Reverting power management..."
    if command -v tuned-adm &>/dev/null; then
        sudo tuned-adm profile balanced 2>/dev/null || true
        echo "  [OK] Tuned profile reset to 'balanced'"
    fi
    sudo rm -rf /etc/tuned/fedora-endurance
    sudo rm -f /etc/modprobe.d/nvidia-power.conf
    sudo rm -f /etc/udev/rules.d/80-nvidia-pm.rules
    sudo rm -f /etc/sysctl.d/99-power.conf
    
    echo "[+] Reverting system optimizations..."
    sudo rm -f /etc/sysctl.d/99-performance.conf
    sudo rm -f /etc/sysctl.d/99-gaming.conf
    sudo rm -f /etc/sysctl.d/99-zram.conf
    sudo rm -f /etc/udev/rules.d/99-io-scheduler.rules
    sudo rm -f /etc/systemd/journald.conf.d/99-optimize.conf
    sudo rm -f /etc/systemd/coredump.conf.d/99-optimize.conf
    sudo rm -f /etc/systemd/resolved.conf.d/99-optimize.conf
    sudo rm -f /etc/systemd/resolved.conf.d/99-doh.conf
    sudo rm -f /etc/security/limits.d/99-performance.conf
    sudo rm -f /etc/profile.d/firefox-wayland.sh
    sudo rm -f /etc/profile.d/firefox-portal.sh
    rm -f "$HOME/.config/chrome-flags.conf"
    rm -f "$HOME/.config/chromium-flags.conf"
    rm -f "$HOME/.config/brave-flags.conf"
    rm -f "$HOME/.config/environment.d/50-portal.conf"

    echo "[+] Reverting network hardening..."
    sudo rm -f /etc/NetworkManager/conf.d/99-wifi-powersave.conf
    sudo rm -f /etc/NetworkManager/conf.d/99-mac-randomization.conf
    sudo rm -f /etc/NetworkManager/conf.d/99-wifi-reconnect.conf
    sudo rm -f /etc/NetworkManager/conf.d/99-ipv6-privacy.conf
    sudo nmcli general reload 2>/dev/null || true

    echo "[+] Reverting hibernate/sleep config..."
    sudo rm -f /etc/systemd/sleep.conf.d/99-fedoraflow.conf
    sudo rm -f /etc/systemd/logind.conf.d/99-lid-hibernate.conf

    echo "[+] Reverting battery threshold..."
    sudo rm -f /etc/udev/rules.d/99-battery-threshold.rules

    echo "[+] Reverting security hardening..."
    sudo rm -f /etc/sysctl.d/99-security.conf
    sudo rm -f /etc/ssh/sshd_config.d/99-hardened.conf
    if command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --set-default-zone=FedoraWorkstation 2>/dev/null || true
        echo "  [OK] Firewall zone reset to FedoraWorkstation"
    fi

    echo "[+] Reloading system configurations..."
    sudo sysctl --system -q 2>/dev/null || true
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true
    sudo systemctl restart systemd-journald 2>/dev/null || true
    if systemctl is-active sshd &>/dev/null; then
        sudo systemctl restart sshd 2>/dev/null || true
    fi

    echo "[+] Reverting GRUB parameters..."
    local grub_file="/etc/default/grub"
    if [[ -f "$grub_file" ]]; then
        sudo sed -i 's/ mem_sleep_default=deep//g' "$grub_file"
        sudo sed -i 's/ nmi_watchdog=0//g' "$grub_file"
        sudo sed -i 's/ pcie_aspm.policy=powersupersave//g' "$grub_file"
        sudo sed -i 's/^GRUB_TIMEOUT=1/GRUB_TIMEOUT=5/' "$grub_file"
        
        if [[ -d /sys/firmware/efi ]]; then
            sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null || true
        else
            sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
        fi
        echo "  [OK] GRUB configuration reverted"
    fi

    echo ""
    echo -e "${GREEN}[OK] Restore complete. Please reboot your system.${NC}"
}
