#!/usr/bin/env bash
# Power management — maximize battery life while keeping good performance
# Adapts to hardware: laptop vs desktop, NVIDIA vs AMD vs Intel

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configure_power() {
    echo ""
    echo "━━━ Power Management Configuration ━━━"

    if [[ "$IS_LAPTOP" == true ]]; then
        echo "[+] Laptop detected — applying battery optimization..."
        setup_tuned_profile
        configure_gpu_power
        configure_kernel_power
        configure_gnome_power_laptop
        configure_battery_threshold
    else
        echo "[+] Desktop detected — applying performance-oriented power config..."
        configure_gpu_power
        configure_gnome_power_desktop
    fi

    echo ""
    echo "[OK] Power management configured"
    echo "[NOTE] Reboot recommended for all changes to take effect"
}

setup_tuned_profile() {
    echo ""
    echo "[+] Setting up tuned power profile..."

    if ! command -v tuned-adm &>/dev/null; then
        echo "  [+] Installing tuned..."
        sudo dnf install -y tuned tuned-ppd 2>&1 | tail -2
    fi

    sudo systemctl enable --now tuned 2>/dev/null

    local profile_dir="/etc/tuned/fedora-endurance"
    if [[ ! -d "$profile_dir" ]]; then
        echo "  [+] Installing custom 'fedora-endurance' tuned profile..."
        sudo mkdir -p "$profile_dir"
        sudo cp "${SCRIPT_DIR}/configs/tuned/fedora-endurance/tuned.conf" "$profile_dir/"
    else
        echo "  [OK] Custom tuned profile already installed"
    fi

    local current
    current=$(tuned-adm active 2>/dev/null | grep -oP 'Current active profile: \K.*')
    if [[ "$current" != "fedora-endurance" ]]; then
        echo "  [+] Activating 'fedora-endurance' profile..."
        sudo tuned-adm profile fedora-endurance 2>/dev/null
    fi

    echo "  [OK] tuned profile: fedora-endurance"
}

configure_gpu_power() {
    case "$GPU_VENDOR" in
        nvidia)
            configure_nvidia_power
            ;;
        amd)
            echo ""
            echo "[+] AMD GPU detected — using kernel default power management"
            echo "  [OK] AMD GPUs handle power management automatically via amdgpu driver"
            ;;
        intel)
            echo ""
            echo "[+] Intel GPU detected — using kernel default power management"
            echo "  [OK] Intel GPUs handle power management automatically via i915 driver"
            ;;
        *)
            echo ""
            echo "[SKIP] No discrete GPU detected — skipping GPU power config"
            ;;
    esac
}

configure_nvidia_power() {
    echo ""
    echo "[+] Configuring NVIDIA runtime power management..."

    local modprobe_file="/etc/modprobe.d/nvidia-power.conf"
    if [[ ! -f "$modprobe_file" ]]; then
        echo "  [+] Enabling NVIDIA Dynamic Power Management (RTD3)..."
        sudo cp "${SCRIPT_DIR}/configs/nvidia-power.conf" "$modprobe_file"
    else
        echo "  [OK] NVIDIA modprobe config already present"
    fi

    local udev_file="/etc/udev/rules.d/80-nvidia-pm.rules"
    if [[ ! -f "$udev_file" ]]; then
        echo "  [+] Adding NVIDIA udev power rules (D3cold suspend)..."
        sudo cp "${SCRIPT_DIR}/configs/nvidia-pm-udev.rules" "$udev_file"
        sudo udevadm control --reload-rules 2>/dev/null
        sudo udevadm trigger 2>/dev/null
    else
        echo "  [OK] NVIDIA udev rules already present"
    fi

    if command -v nvidia-smi &>/dev/null; then
        echo "  [+] Setting NVIDIA persistence mode..."
        sudo nvidia-smi -pm 1 2>/dev/null || true
    fi

    local nvidia_services=(
        "nvidia-suspend.service"
        "nvidia-hibernate.service"
        "nvidia-resume.service"
    )
    for svc in "${nvidia_services[@]}"; do
        if systemctl list-unit-files "$svc" &>/dev/null; then
            sudo systemctl enable "$svc" 2>/dev/null || true
        fi
    done

    echo "  [OK] NVIDIA GPU will now suspend when idle (saves 5-15W)"
}

configure_kernel_power() {
    echo ""
    echo "[+] Applying kernel power parameters..."

    local sysctl_file="/etc/sysctl.d/99-power.conf"
    if [[ ! -f "$sysctl_file" ]] || ! grep -q "laptop_mode" "$sysctl_file" 2>/dev/null; then
        sudo cp "${SCRIPT_DIR}/configs/sysctl-power.conf" "$sysctl_file"
        sudo sysctl --system -q 2>/dev/null
        echo "  [OK] Kernel parameters applied"
    else
        echo "  [OK] Kernel power parameters already configured"
    fi

    local grub_file="/etc/default/grub"
    local grub_needs_update=false

    if [[ -f "$grub_file" ]]; then
        local current_cmdline
        current_cmdline=$(grep "^GRUB_CMDLINE_LINUX=" "$grub_file" 2>/dev/null || echo "")

        declare -A grub_params=(
            ["mem_sleep_default"]="deep"
            ["nmi_watchdog"]="0"
            ["pcie_aspm.policy"]="powersupersave"
        )

        for param in "${!grub_params[@]}"; do
            if ! echo "$current_cmdline" | grep -q "$param"; then
                echo "  [+] Adding kernel parameter: ${param}=${grub_params[$param]}"
                sudo sed -i "s/\(GRUB_CMDLINE_LINUX=\"[^\"]*\)/\1 ${param}=${grub_params[$param]}/" "$grub_file"
                grub_needs_update=true
            fi
        done

        if [[ "$grub_needs_update" == true ]]; then
            echo "  [+] Regenerating GRUB config..."
            if [[ -d /sys/firmware/efi ]]; then
                sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null
            else
                sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
            fi
            echo "  [OK] GRUB updated (reboot needed)"
        fi
    fi
}

configure_gnome_power_laptop() {
    echo ""
    echo "[+] Configuring GNOME power settings (laptop)..."

    if ! require_gnome; then
        return 0
    fi

    gsettings set org.gnome.desktop.interface show-battery-percentage true

    gsettings set org.gnome.settings-daemon.plugins.power idle-dim true
    gsettings set org.gnome.settings-daemon.plugins.power idle-brightness 30
    gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled true

    gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery true

    # AC: never auto-suspend, just dim + blank screen
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0

    # Battery: suspend after 30 minutes of idle
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800

    # Screen blank after 10 min
    gsettings set org.gnome.desktop.session idle-delay 600

    echo "  [OK] Laptop power settings:"
    echo "       AC      → never suspend, screen dims after 10 min"
    echo "       Battery → suspend after 30 min, screen dims after 10 min"
    echo "       Low battery → auto-switch to power-saver profile"
    echo "       Battery percentage shown in top bar"
}

configure_gnome_power_desktop() {
    echo ""
    echo "[+] Configuring GNOME power settings (desktop)..."

    if ! require_gnome; then
        return 0
    fi

    gsettings set org.gnome.settings-daemon.plugins.power idle-dim false

    # Desktop: never suspend, screen blanks after 15 min
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
    gsettings set org.gnome.desktop.session idle-delay 900

    echo "  [OK] Desktop power settings:"
    echo "       Never suspend, screen blanks after 15 min"
}

configure_battery_threshold() {
    echo ""
    echo "[+] Configuring battery charge thresholds..."

    local bat_path=""
    for bat in /sys/class/power_supply/BAT{0,1}; do
        if [[ -f "${bat}/charge_start_threshold" ]]; then
            bat_path="$bat"
            break
        fi
    done

    if [[ -z "$bat_path" ]]; then
        echo "  [SKIP] No charge threshold support detected"
        return 0
    fi

    local current_start current_end
    current_start=$(cat "${bat_path}/charge_start_threshold" 2>/dev/null)
    current_end=$(cat "${bat_path}/charge_end_threshold" 2>/dev/null)

    if [[ "$current_start" == "75" ]] && [[ "$current_end" == "80" ]]; then
        echo "  [OK] Charge thresholds already set (75-80%) — optimal for longevity"
    else
        echo "  [+] Setting charge thresholds to 75-80% (maximizes battery lifespan)..."
        echo 75 | sudo tee "${bat_path}/charge_start_threshold" > /dev/null 2>&1
        echo 80 | sudo tee "${bat_path}/charge_end_threshold" > /dev/null 2>&1
        echo "  [OK] Charge thresholds set to 75-80%"
    fi
}
