#!/usr/bin/env bash
# Printer/Scanner Auto-Setup — CUPS, SANE, IPP Everywhere, common drivers
# Makes printers "just work" on Fedora

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_printer_scanner() {
    echo ""
    echo "━━━ Printer & Scanner Setup ━━━"

    install_cups
    install_scanner_support
    install_common_drivers
    configure_avahi

    echo ""
    echo "[OK] Printer & scanner support configured"
}

install_cups() {
    echo ""
    echo "[+] Setting up CUPS print server..."

    local packages=(
        cups
        cups-filters
        cups-pdf
        system-config-printer
    )

    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null 2>&1; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        sudo dnf install -y "${to_install[@]}" 2>&1 | tail -3
    fi

    sudo systemctl enable --now cups.service 2>/dev/null
    sudo systemctl enable --now cups-browsed.service 2>/dev/null || true

    echo "  [OK] CUPS print server active"
    echo "  [OK] Print to PDF enabled (virtual printer)"
}

install_scanner_support() {
    echo ""
    echo "[+] Installing scanner support (SANE)..."

    local packages=(
        sane-backends
        sane-backends-drivers-scanners
        simple-scan
    )

    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null 2>&1; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        sudo dnf install -y "${to_install[@]}" 2>&1 | tail -3
        echo "  [OK] SANE scanner backends installed"
    else
        echo "  [OK] Scanner support already installed"
    fi
}

install_common_drivers() {
    echo ""
    echo "[+] Installing common printer drivers..."

    local packages=(
        gutenprint
        gutenprint-cups
        hplip
        foomatic-db
        foomatic-db-ppds
    )

    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null 2>&1; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        sudo dnf install -y --skip-unavailable "${to_install[@]}" 2>&1 | tail -3
        echo "  [OK] Printer drivers installed:"
    else
        echo "  [OK] Printer drivers already installed:"
    fi

    echo "       • Gutenprint (Canon, Epson, HP, Lexmark, and more)"
    echo "       • HPLIP (HP printers and scanners)"
    echo "       • Foomatic (generic PPD database)"
}

configure_avahi() {
    echo ""
    echo "[+] Configuring network printer discovery (Avahi/mDNS)..."

    if ! rpm -q avahi &>/dev/null; then
        sudo dnf install -y avahi avahi-tools nss-mdns 2>&1 | tail -2
    fi

    sudo systemctl enable --now avahi-daemon.service 2>/dev/null

    if command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --permanent --add-service=mdns 2>/dev/null
        sudo firewall-cmd --permanent --add-service=ipp 2>/dev/null
        sudo firewall-cmd --permanent --add-service=ipp-client 2>/dev/null
        sudo firewall-cmd --reload 2>/dev/null
    fi

    echo "  [OK] Avahi mDNS active — network printers will auto-discover"
    echo "  [OK] IPP/IPP-Everywhere firewall rules added"
    echo ""
    echo "  To add a printer:"
    echo "    • GNOME Settings > Printers (auto-discovers network printers)"
    echo "    • Or: system-config-printer (advanced)"
    echo "    • Or: http://localhost:631 (CUPS web interface)"
}
