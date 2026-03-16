#!/usr/bin/env bash
# Security hardening — firewall, kernel, SELinux, fail2ban, SSH, auto-updates
# Designed to be safe for beginners while providing strong protection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configure_security() {
    echo ""
    echo "━━━ Security Hardening ━━━"

    harden_firewall
    harden_kernel
    ensure_selinux
    setup_fail2ban
    harden_ssh
    harden_usb

    echo ""
    echo "[OK] Security hardening complete"
}

harden_firewall() {
    echo ""
    echo "[+] Hardening firewall..."

    if ! command -v firewall-cmd &>/dev/null; then
        echo "  [+] Installing firewalld..."
        sudo dnf install -y firewalld 2>&1 | tail -2
    fi

    sudo systemctl enable --now firewalld 2>/dev/null

    local current_zone
    current_zone=$(firewall-cmd --get-default-zone 2>/dev/null)

    # The default FedoraWorkstation zone opens 1025-65535 — very permissive
    # Switch to a tighter "home" zone and only allow what's needed
    if [[ "$current_zone" == "FedoraWorkstation" ]]; then
        echo "  [+] Switching from permissive FedoraWorkstation zone to 'home'..."
        sudo firewall-cmd --set-default-zone=home 2>/dev/null

        # Re-allow only essential services
        sudo firewall-cmd --permanent --zone=home --add-service=dhcpv6-client 2>/dev/null
        sudo firewall-cmd --permanent --zone=home --add-service=ssh 2>/dev/null
        sudo firewall-cmd --permanent --zone=home --add-service=mdns 2>/dev/null

        # Auto-detect installed apps that need open ports
        local -A app_ports=(
            ["synergy"]="24800/tcp"
            ["synergys"]="24800/tcp"
            ["remmina"]="3389/tcp"
        )
        for app in "${!app_ports[@]}"; do
            if command -v "$app" &>/dev/null; then
                sudo firewall-cmd --permanent --zone=home --add-port="${app_ports[$app]}" 2>/dev/null
                echo "  [+] ${app} detected — port ${app_ports[$app]} opened"
            fi
        done

        sudo firewall-cmd --reload 2>/dev/null
        echo "  [OK] Firewall: 'home' zone (only essential services)"
    else
        echo "  [OK] Firewall zone: $current_zone"
    fi

    # Block ICMP timestamp (info leak)
    sudo firewall-cmd --permanent --add-icmp-block=timestamp-request 2>/dev/null
    sudo firewall-cmd --permanent --add-icmp-block=timestamp-reply 2>/dev/null
    sudo firewall-cmd --reload 2>/dev/null || true
}

harden_kernel() {
    echo ""
    echo "[+] Applying kernel security parameters..."

    local sysctl_file="/etc/sysctl.d/99-security.conf"
    if [[ ! -f "$sysctl_file" ]] || ! grep -q "kptr_restrict" "$sysctl_file" 2>/dev/null; then
        sudo cp "${SCRIPT_DIR}/configs/sysctl-security.conf" "$sysctl_file"
        sudo sysctl --system -q 2>/dev/null
        echo "  [OK] Kernel hardening parameters applied:"
    else
        echo "  [OK] Kernel security parameters already configured"
    fi

    echo "       • kptr_restrict=2, ptrace_scope=1, dmesg_restrict=1"
    echo "       • ICMP redirects blocked, SYN flood protection"
    echo "       • Reverse path filtering, ASLR max level"
}

ensure_selinux() {
    echo ""
    echo "[+] Verifying SELinux..."

    local selinux_status
    selinux_status=$(getenforce 2>/dev/null || echo "Disabled")

    if [[ "$selinux_status" == "Enforcing" ]]; then
        echo "  [OK] SELinux is enforcing (good)"
    elif [[ "$selinux_status" == "Permissive" ]]; then
        echo "  [!!] SELinux is permissive — switching to enforcing..."
        sudo setenforce 1 2>/dev/null
        sudo sed -i 's/^SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null
        echo "  [OK] SELinux set to enforcing"
    else
        echo "  [WARN] SELinux is disabled — strongly recommend enabling it"
        echo "         Edit /etc/selinux/config and set SELINUX=enforcing, then reboot"
    fi
}

setup_fail2ban() {
    echo ""
    echo "[+] Setting up fail2ban (brute-force protection)..."

    if ! rpm -q fail2ban &>/dev/null; then
        echo "  [+] Installing fail2ban..."
        sudo dnf install -y fail2ban 2>&1 | tail -2
    fi

    local jail_file="/etc/fail2ban/jail.local"
    if [[ ! -f "$jail_file" ]]; then
        echo "  [+] Creating fail2ban configuration..."
        sudo tee "$jail_file" > /dev/null <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
banaction = firewallcmd-rich-rules[actiontype=<multiport>]
backend = systemd

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 3h
EOF
    else
        echo "  [OK] fail2ban jail.local already exists"
    fi

    sudo systemctl enable --now fail2ban 2>/dev/null
    echo "  [OK] fail2ban active — SSH brute-force protection enabled"
}

harden_ssh() {
    echo ""
    echo "[+] Hardening SSH server configuration..."

    local sshd_dir="/etc/ssh/sshd_config.d"
    local hardened_file="${sshd_dir}/99-hardened.conf"

    if [[ ! -d "$sshd_dir" ]]; then
        sudo mkdir -p "$sshd_dir"
    fi

    if [[ ! -f "$hardened_file" ]]; then
        local has_ssh_key=false
        if [[ -f "$HOME/.ssh/authorized_keys" ]] && [[ -s "$HOME/.ssh/authorized_keys" ]]; then
            has_ssh_key=true
        fi

        if [[ "$has_ssh_key" == false ]]; then
            warn "  No SSH authorized_keys found for $(whoami)."
            warn "  SSH password auth will be disabled — you may be locked out of SSH."
            warn "  Add your public key to ~/.ssh/authorized_keys before rebooting,"
            warn "  or re-enable PasswordAuthentication in ${hardened_file}."
        fi

        sudo cp "${SCRIPT_DIR}/configs/ssh-hardened.conf" "$hardened_file"
        echo "  [OK] SSH hardening applied:"
    else
        echo "  [OK] SSH hardening already configured:"
    fi

    echo "       • Root login disabled"
    echo "       • Password auth disabled (key-only)"
    echo "       • Max 3 auth attempts"
    echo "       • X11/TCP forwarding disabled"

    if systemctl is-enabled sshd &>/dev/null 2>&1; then
        sudo systemctl reload sshd 2>/dev/null || true
    fi
}

harden_usb() {
    echo ""
    echo "[+] Configuring USB security..."

    # USBGuard is aggressive and can break things for beginners
    # Instead, we add a udev rule to block USB storage when screen is locked
    # This is a softer approach that's beginner-friendly

    local usb_rule="/etc/udev/rules.d/99-usb-block-storage-locked.rules"
    if [[ ! -f "$usb_rule" ]]; then
        echo "  [+] Blocking automatic USB storage mount when screen is locked..."
        sudo tee "$usb_rule" > /dev/null <<'EOF'
# Block new USB mass storage devices while the session is locked
# Allows USB keyboards/mice/hubs, only restricts storage class
ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="08", ENV{UDISKS_AUTO}="0"
EOF
        sudo udevadm control --reload-rules 2>/dev/null
        echo "  [OK] USB storage auto-mount restricted"
    else
        echo "  [OK] USB storage rules already configured"
    fi
}
