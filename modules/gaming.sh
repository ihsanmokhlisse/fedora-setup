#!/usr/bin/env bash
# Gaming tweaks — Steam, Lutris, Gamemode, Kernel max_map_count

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_gaming_env() {
    echo ""
    echo -e "${BOLD}━━━ Setting up Gaming Environment ━━━${NC}"

    optimize_kernel_gaming
    install_gaming_packages

    echo ""
    echo "[OK] Gaming environment configured"
}

optimize_kernel_gaming() {
    echo ""
    echo "[+] Applying gaming kernel parameters..."

    # Required for heavy games like Cyberpunk 2077, Hogwarts Legacy, Star Citizen
    local sysctl_file="/etc/sysctl.d/99-gaming.conf"
    if [[ ! -f "$sysctl_file" ]] || ! grep -q "max_map_count" "$sysctl_file" 2>/dev/null; then
        sudo tee "$sysctl_file" > /dev/null <<EOF
vm.max_map_count = 2147483642
EOF
        sudo sysctl --system -q 2>/dev/null
        echo "  [OK] vm.max_map_count increased (prevents crashes in heavy games)"
    else
        echo "  [OK] Gaming kernel parameters already configured"
    fi
}

install_gaming_packages() {
    echo ""
    echo "[+] Installing gaming packages and 32-bit libraries..."

    # Ensure 32-bit libraries required by Steam/Proton are present
    local pkgs=(
        steam
        lutris
        gamemode
        mangohud
        vulkan-loader.i686
        mesa-vulkan-drivers.i686
        pipewire-alsa.i686
    )

    sudo dnf install -y --skip-unavailable "${pkgs[@]}" 2>&1 | tail -3
    
    # Add user to gamemode group
    if ! groups "$USER" | grep -q '\bgamemode\b'; then
        sudo usermod -aG gamemode "$USER" 2>/dev/null || true
    fi

    echo "  [OK] Steam, Lutris, Gamemode, and 32-bit libraries installed"
}
