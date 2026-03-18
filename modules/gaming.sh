#!/usr/bin/env bash
# Gaming tweaks — kernel scheduler, Proton-GE, Gamescope, Wine, MangoHud, corectrl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_gaming_env() {
    echo ""
    echo -e "${BOLD}━━━ Setting up Gaming Environment ━━━${NC}"

    optimize_kernel_gaming
    install_gaming_packages
    install_proton_ge
    install_gamescope
    install_wine_deps
    install_gpu_tools
    configure_mangohud

    echo ""
    echo "[OK] Gaming environment configured"
}

optimize_kernel_gaming() {
    echo ""
    echo "[+] Applying gaming kernel parameters..."

    local sysctl_file="/etc/sysctl.d/99-gaming.conf"
    if [[ ! -f "$sysctl_file" ]] || ! grep -q "max_map_count" "$sysctl_file" 2>/dev/null; then
        sudo tee "$sysctl_file" > /dev/null <<EOF
# Prevent crashes in heavy games (Cyberpunk 2077, Hogwarts Legacy, Star Citizen)
vm.max_map_count = 2147483642

# Disable autogroup scheduler — lets Gamemode and nice levels work properly
kernel.sched_autogroup_enabled = 0

# Reduce scheduler latency for smoother frame pacing
kernel.sched_latency_ns = 4000000
kernel.sched_min_granularity_ns = 500000
kernel.sched_wakeup_granularity_ns = 500000

# Disable Nagle's algorithm delay for lower online game latency
net.ipv4.tcp_low_latency = 1
EOF
        sudo sysctl --system -q 2>/dev/null
        echo "  [OK] Gaming kernel parameters applied:"
        echo "       vm.max_map_count, scheduler tuning, tcp_low_latency"
    else
        echo "  [OK] Gaming kernel parameters already configured"
    fi
}

install_gaming_packages() {
    echo ""
    echo "[+] Installing core gaming packages and 32-bit libraries..."

    local pkgs=(
        steam
        lutris
        gamemode
        mangohud
        mangohud.i686
        vulkan-loader
        vulkan-loader.i686
        mesa-vulkan-drivers
        mesa-vulkan-drivers.i686
        mesa-libGL.i686
        mesa-dri-drivers.i686
        pipewire-alsa.i686
        libgcc.i686
        glibc.i686
    )

    sudo dnf install -y --skip-unavailable "${pkgs[@]}" 2>&1 | tail -3

    if ! groups "$USER" | grep -q '\bgamemode\b'; then
        sudo usermod -aG gamemode "$USER" 2>/dev/null || true
    fi

    echo "  [OK] Steam, Lutris, Gamemode, MangoHud, and 32-bit Vulkan installed"
}

install_proton_ge() {
    echo ""
    echo "[+] Installing ProtonUp-Qt (Proton-GE manager)..."

    if ! flatpak info net.davidotek.pupgui2 &>/dev/null; then
        flatpak install -y flathub net.davidotek.pupgui2 2>&1 | tail -2
        echo "  [OK] ProtonUp-Qt installed"
        echo "  [NOTE] Open ProtonUp-Qt and click 'Add version' to install Proton-GE"
    else
        echo "  [OK] ProtonUp-Qt already installed"
    fi
}

install_gamescope() {
    echo ""
    echo "[+] Installing Gamescope (Valve's micro-compositor)..."

    if ! command -v gamescope &>/dev/null; then
        sudo dnf install -y --skip-unavailable gamescope 2>&1 | tail -2
    fi

    echo "  [OK] Gamescope installed"
    echo "  [NOTE] Launch games with: gamescope -W 1920 -H 1080 -f -- %command%"
}

install_wine_deps() {
    echo ""
    echo "[+] Installing Wine and dependencies for Lutris games..."

    local pkgs=(
        wine
        wine-core
        wine-core.i686
        wine-pulseaudio
        wine-pulseaudio.i686
        winetricks
        cabextract
        samba-winbind-clients
    )

    sudo dnf install -y --skip-unavailable "${pkgs[@]}" 2>&1 | tail -3
    echo "  [OK] Wine stack installed (required for non-Steam games in Lutris)"
}

install_gpu_tools() {
    echo ""
    echo "[+] Installing GPU management tools..."

    case "$GPU_VENDOR" in
        nvidia)
            sudo dnf install -y --skip-unavailable nvidia-settings 2>&1 | tail -1

            # Enable Coolbits for fan/clock control in nvidia-settings
            local xconf="/etc/X11/xorg.conf.d/99-nvidia-coolbits.conf"
            if [[ ! -f "$xconf" ]] && [[ "$IS_WAYLAND" != true ]]; then
                sudo mkdir -p /etc/X11/xorg.conf.d
                sudo tee "$xconf" > /dev/null <<EOF
Section "Device"
    Identifier "Device0"
    Driver "nvidia"
    Option "Coolbits" "28"
EndSection
EOF
                echo "  [OK] NVIDIA Coolbits enabled (fan curve + clock control)"
            fi
            echo "  [OK] nvidia-settings installed"
            ;;
        amd)
            if ! command -v corectrl &>/dev/null; then
                sudo dnf install -y --skip-unavailable corectrl 2>&1 | tail -1
            fi

            # Allow corectrl to run without root password
            local polkit_file="/etc/polkit-1/rules.d/90-corectrl.rules"
            if [[ ! -f "$polkit_file" ]]; then
                sudo tee "$polkit_file" > /dev/null <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.corectrl.helper.init" ||
         action.id == "org.corectrl.helperkiller.init") &&
        subject.local == true &&
        subject.active == true &&
        subject.isInGroup("wheel")) {
            return polkit.Result.YES;
    }
});
EOF
                echo "  [OK] CoreCtrl installed (GPU power, fan, clock control for AMD)"
            fi
            ;;
        *)
            echo "  [SKIP] No discrete GPU tools needed for Intel iGPU"
            ;;
    esac
}

configure_mangohud() {
    echo ""
    echo "[+] Configuring MangoHud overlay..."

    local mangohud_dir="$HOME/.config/MangoHud"
    mkdir -p "$mangohud_dir"

    local mangohud_conf="${mangohud_dir}/MangoHud.conf"
    if [[ ! -f "$mangohud_conf" ]]; then
        cat > "$mangohud_conf" <<EOF
### FedoraFlow MangoHud Config ###

# Position & Appearance
position=top-left
font_size=20
background_alpha=0.4
round_corners=8

# Metrics
fps
frametime=0
cpu_stats
cpu_temp
gpu_stats
gpu_temp
ram
vram
engine_version

# Logging (press F2 to start/stop a log)
output_folder=$HOME/mangohud-logs
log_duration=60

# Toggle overlay with Right Shift + F12
toggle_hud=Shift_R+F12
toggle_fps_limit=Shift_R+F1
EOF
        echo "  [OK] MangoHud configured (toggle: Right Shift + F12)"
    else
        echo "  [OK] MangoHud config already present"
    fi
}
