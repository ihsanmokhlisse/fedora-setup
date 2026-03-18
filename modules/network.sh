#!/usr/bin/env bash
# Network Hardening — WiFi power-save off, MAC randomization, faster reconnect
# Fixes common WiFi lag spikes and improves privacy on public networks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

harden_network() {
    echo ""
    echo "━━━ Network Hardening ━━━"

    disable_wifi_powersave
    enable_mac_randomization
    optimize_wifi_reconnect
    harden_ipv6

    echo ""
    echo "[OK] Network hardening complete"
}

disable_wifi_powersave() {
    echo ""
    echo "[+] Disabling WiFi power-save (fixes lag spikes)..."

    local wifi_conf="/etc/NetworkManager/conf.d/99-wifi-powersave.conf"
    if [[ ! -f "$wifi_conf" ]]; then
        sudo tee "$wifi_conf" > /dev/null <<'EOF'
[connection]
wifi.powersave = 2
EOF
        echo "  [OK] WiFi power-save disabled (2 = off)"
    else
        echo "  [OK] WiFi power-save already configured"
    fi
}

enable_mac_randomization() {
    echo ""
    echo "[+] Enabling MAC address randomization for privacy..."

    local mac_conf="/etc/NetworkManager/conf.d/99-mac-randomization.conf"
    if [[ ! -f "$mac_conf" ]]; then
        sudo tee "$mac_conf" > /dev/null <<'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=stable
ethernet.cloned-mac-address=stable
connection.stable-id=${CONNECTION}/${BOOT}
EOF
        echo "  [OK] MAC randomization: random during scan, stable per-network per-boot"
    else
        echo "  [OK] MAC randomization already configured"
    fi
}

optimize_wifi_reconnect() {
    echo ""
    echo "[+] Optimizing WiFi reconnection speed..."

    local wifi_conf="/etc/NetworkManager/conf.d/99-wifi-reconnect.conf"
    if [[ ! -f "$wifi_conf" ]]; then
        sudo tee "$wifi_conf" > /dev/null <<'EOF'
[connectivity]
interval=300

[main]
autoconnect-retries-default=3
EOF
        echo "  [OK] WiFi reconnection optimized (3 retries, 5min connectivity check)"
    else
        echo "  [OK] WiFi reconnection already optimized"
    fi
}

harden_ipv6() {
    echo ""
    echo "[+] Hardening IPv6 privacy..."

    local ipv6_conf="/etc/NetworkManager/conf.d/99-ipv6-privacy.conf"
    if [[ ! -f "$ipv6_conf" ]]; then
        sudo tee "$ipv6_conf" > /dev/null <<'EOF'
[connection]
ipv6.ip6-privacy=2
EOF
        echo "  [OK] IPv6 privacy extensions enabled (RFC 4941)"
    else
        echo "  [OK] IPv6 privacy already configured"
    fi

    sudo nmcli general reload 2>/dev/null || true
}
