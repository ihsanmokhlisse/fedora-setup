#!/usr/bin/env bash
# System optimization — boot, DNF, kernel, network, I/O, memory, services
# Makes Fedora as fast and responsive as possible

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

optimize_system() {
    echo ""
    echo "━━━ System Optimization ━━━"

    optimize_dnf
    optimize_boot
    optimize_kernel
    optimize_io
    optimize_memory
    optimize_zram
    optimize_services
    optimize_journal
    optimize_btrfs
    optimize_limits
    optimize_browsers
    optimize_dns
    optimize_time_sync

    echo ""
    echo "[OK] System optimization complete"
    echo "[NOTE] Reboot for all changes to take effect"
}

optimize_dnf() {
    echo ""
    echo "[+] Optimizing DNF package manager..."

    local dnf_conf="/etc/dnf/dnf.conf"

    if [[ ! -f "$dnf_conf" ]]; then
        echo "  [SKIP] DNF config not found"
        return 0
    fi

    declare -A dnf_opts=(
        ["max_parallel_downloads"]="10"
        ["fastestmirror"]="True"
        ["defaultyes"]="True"
        ["install_weak_deps"]="False"
        ["keepcache"]="False"
    )

    for key in "${!dnf_opts[@]}"; do
        if ! grep -q "^${key}=" "$dnf_conf" 2>/dev/null; then
            echo "${key}=${dnf_opts[$key]}" | sudo tee -a "$dnf_conf" > /dev/null
            echo "  [+] ${key}=${dnf_opts[$key]}"
        fi
    done

    echo "  [OK] DNF: 10 parallel downloads, fastest mirror, delta RPMs"
}

optimize_boot() {
    echo ""
    echo "[+] Optimizing boot time..."

    local grub_file="/etc/default/grub"

    if [[ -f "$grub_file" ]]; then
        local current_timeout
        current_timeout=$(grep "^GRUB_TIMEOUT=" "$grub_file" | cut -d= -f2)

        if [[ "$current_timeout" =~ ^[0-9]+$ ]] && [[ "$current_timeout" -gt 1 ]]; then
            sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' "$grub_file"
            echo "  [+] GRUB timeout: ${current_timeout}s → 1s"

            if [[ -d /sys/firmware/efi ]]; then
                sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null
            else
                sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
            fi
        else
            echo "  [OK] GRUB timeout already optimized"
        fi
    fi

    # Detect slow non-essential boot services and suggest deferring them
    local slow_services
    slow_services=$(systemd-analyze blame 2>/dev/null | \
        awk '$1 ~ /^[0-9]+\.[0-9]+s$/ && $1+0 > 10 {print $2}' | \
        grep -vE 'kernel|initrd|firmware|dracut|luks|lvm|network|gdm|gnome|systemd|udev|firewalld|selinux|akmods|fstrim' | \
        head -5)

    if [[ -n "$slow_services" ]]; then
        for svc in $slow_services; do
            if systemctl is-enabled "$svc" &>/dev/null; then
                echo "  [!] Slow boot service detected: $svc"
                echo "      Consider disabling or deferring it to a user service"
            fi
        done
    fi

    echo "  [OK] Boot optimized"
}

optimize_kernel() {
    echo ""
    echo "[+] Applying kernel performance parameters..."

    local sysctl_file="/etc/sysctl.d/99-performance.conf"
    if [[ ! -f "$sysctl_file" ]] || ! grep -q "tcp_congestion_control" "$sysctl_file" 2>/dev/null; then
        sudo cp "${SCRIPT_DIR}/configs/sysctl-performance.conf" "$sysctl_file"
        sudo sysctl --system -q 2>/dev/null
        echo "  [OK] Applied:"
    else
        echo "  [OK] Kernel performance parameters already configured:"
    fi

    echo "       • TCP BBR congestion control"
    echo "       • TCP Fast Open (client+server)"
    echo "       • 16MB network buffers"
    echo "       • 524288 inotify watchers (IDE-friendly)"
    echo "       • Increased file descriptor limits"
}

optimize_io() {
    echo ""
    echo "[+] Optimizing disk I/O..."

    for disk in /sys/block/nvme* /sys/block/sd*; do
        [[ -d "$disk" ]] || continue
        local name=$(basename "$disk")
        local rotational=$(cat "${disk}/queue/rotational" 2>/dev/null)

        if [[ "$rotational" == "0" ]]; then
            local current_ra=$(cat "${disk}/queue/read_ahead_kb" 2>/dev/null)
            if [[ "$current_ra" -lt 2048 ]] 2>/dev/null; then
                echo 2048 | sudo tee "${disk}/queue/read_ahead_kb" > /dev/null 2>&1
                echo "  [+] ${name}: read-ahead ${current_ra}KB → 2048KB"
            fi

            local nr_requests=$(cat "${disk}/queue/nr_requests" 2>/dev/null)
            if [[ -n "$nr_requests" ]] && [[ "$nr_requests" -lt 512 ]] 2>/dev/null; then
                echo 512 | sudo tee "${disk}/queue/nr_requests" > /dev/null 2>&1
                echo "  [+] ${name}: nr_requests → 512"
            fi
        fi
    done

    local udev_io="/etc/udev/rules.d/99-io-scheduler.rules"
    if [[ ! -f "$udev_io" ]]; then
        sudo tee "$udev_io" > /dev/null <<'EOF'
# NVMe/SSD: none scheduler (lowest overhead), high read-ahead
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none", ATTR{queue/read_ahead_kb}="2048"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none", ATTR{queue/read_ahead_kb}="2048"
# HDD: BFQ scheduler (best for rotational)
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
        sudo udevadm control --reload-rules 2>/dev/null
        echo "  [OK] I/O scheduler rules persisted via udev"
    fi

    if ! systemctl is-enabled fstrim.timer &>/dev/null; then
        sudo systemctl enable --now fstrim.timer 2>/dev/null
        echo "  [+] TRIM timer enabled"
    else
        echo "  [OK] TRIM timer already active"
    fi

    echo "  [OK] Disk I/O optimized"
}

optimize_memory() {
    echo ""
    echo "[+] Optimizing memory management..."

    if ! rpm -q earlyoom &>/dev/null; then
        echo "  [+] Installing earlyoom (OOM prevention)..."
        sudo dnf install -y earlyoom 2>&1 | tail -2
        sudo systemctl enable --now earlyoom 2>/dev/null
        echo "  [OK] earlyoom active — prevents system freeze on low memory"
    else
        sudo systemctl enable --now earlyoom 2>/dev/null
        echo "  [OK] earlyoom already installed and active"
    fi

    if command -v zramctl &>/dev/null; then
        local current_algo
        current_algo=$(zramctl --output ALGORITHM --noheadings 2>/dev/null | head -1 | tr -d ' ')
        echo "  [OK] zram swap active (algorithm: ${current_algo:-unknown})"
    fi

    echo "  [OK] Memory optimized"
}

optimize_zram() {
    echo ""
    echo "[+] Optimizing ZRAM for maximum memory efficiency..."

    local zram_conf="/etc/systemd/zram-generator.conf"
    
    if [[ ! -f "$zram_conf" ]] || ! grep -q "compression-algorithm=zstd" "$zram_conf" 2>/dev/null; then
        sudo tee "$zram_conf" > /dev/null <<EOF
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
        sudo systemctl daemon-reload 2>/dev/null
        sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true
        echo "  [OK] ZRAM configured: 100% RAM size, zstd compression"
    else
        echo "  [OK] ZRAM already optimized"
    fi

    # Optimize sysctl for ZRAM
    local sysctl_zram="/etc/sysctl.d/99-zram.conf"
    if [[ ! -f "$sysctl_zram" ]]; then
        sudo tee "$sysctl_zram" > /dev/null <<EOF
vm.swappiness = 100
vm.watermark_scale_factor = 125
vm.watermark_boost_factor = 0
vm.page-cluster = 0
EOF
        sudo sysctl --system -q 2>/dev/null
        echo "  [OK] Kernel parameters tuned for ZRAM (swappiness=100)"
    fi
}

optimize_services() {
    echo ""
    echo "[+] Disabling unnecessary services..."

    local services_to_disable=(
        "atd.service"
        "ModemManager.service"
        "mcelog.service"
        "raid-check.timer"
        "lvm2-monitor.service"
    )

    for svc in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
            # ModemManager: only disable if no cellular modem
            if [[ "$svc" == "ModemManager.service" ]]; then
                if mmcli -L 2>/dev/null | grep -q "Modem"; then
                    echo "  [SKIP] $svc — cellular modem detected"
                    continue
                fi
            fi

            # LVM: only disable if no LVM volumes
            if [[ "$svc" == "lvm2-monitor.service" ]]; then
                if pvs 2>/dev/null | grep -q "/dev/"; then
                    echo "  [SKIP] $svc — LVM volumes detected"
                    continue
                fi
            fi

            sudo systemctl disable --now "$svc" 2>/dev/null
            sudo systemctl mask "$svc" 2>/dev/null
            echo "  [+] Disabled: $svc"
        fi
    done

    echo "  [OK] Unnecessary services disabled"
}

optimize_journal() {
    echo ""
    echo "[+] Optimizing systemd journal..."

    local journal_conf="/etc/systemd/journald.conf.d"
    sudo mkdir -p "$journal_conf"

    local journal_file="${journal_conf}/99-optimize.conf"
    if [[ ! -f "$journal_file" ]]; then
        sudo tee "$journal_file" > /dev/null <<'EOF'
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=10M
MaxRetentionSec=1week
Compress=yes
EOF
        sudo systemctl restart systemd-journald 2>/dev/null
        echo "  [OK] Journal capped at 100MB, 1 week retention"
    else
        echo "  [OK] Journal already optimized"
    fi

    local coredump_conf="/etc/systemd/coredump.conf.d"
    sudo mkdir -p "$coredump_conf"

    local coredump_file="${coredump_conf}/99-optimize.conf"
    if [[ ! -f "$coredump_file" ]]; then
        sudo tee "$coredump_file" > /dev/null <<'EOF'
[Coredump]
Storage=none
ProcessSizeMax=0
EOF
        echo "  [OK] Core dumps disabled (saves disk space)"
    else
        echo "  [OK] Core dump config already optimized"
    fi
}

optimize_btrfs() {
    echo ""
    echo "[+] Optimizing Btrfs filesystem..."

    if ! mount | grep -q "type btrfs"; then
        echo "  [SKIP] No Btrfs filesystem detected"
        return 0
    fi

    local fstab="/etc/fstab"

    if grep -q "btrfs" "$fstab" && ! grep "btrfs" "$fstab" | grep -q "noatime"; then
        echo "  [+] Adding noatime to Btrfs mount options..."
        sudo sed -i '/btrfs/ s/defaults/defaults,noatime/; /btrfs/ { /defaults/! s/subvol=/noatime,subvol=/ }' "$fstab"
        echo "  [OK] noatime added (reduces unnecessary disk writes)"
        echo "  [NOTE] Will take effect after reboot"
    else
        echo "  [OK] Btrfs mount options already include noatime or no btrfs in fstab"
    fi

    if mount | grep -q "compress=zstd"; then
        echo "  [OK] Btrfs zstd compression active"
    fi

    if mount | grep -q "discard=async"; then
        echo "  [OK] Btrfs async discard active"
    fi

    if mount | grep -q "space_cache=v2"; then
        echo "  [OK] Btrfs space_cache v2 active"
    fi
}

optimize_limits() {
    echo ""
    echo "[+] Setting system limits..."

    local limits_file="/etc/security/limits.d/99-performance.conf"
    if [[ ! -f "$limits_file" ]]; then
        sudo cp "${SCRIPT_DIR}/configs/limits-performance.conf" "$limits_file"
        echo "  [OK] File descriptor limits increased (65536 soft / 524288 hard)"
    else
        echo "  [OK] System limits already configured"
    fi
}

optimize_browsers() {
    echo ""
    echo "[+] Optimizing web browsers (Wayland & Hardware Acceleration)..."

    # Firefox: Force Wayland via environment variable
    local profile_d="/etc/profile.d/firefox-wayland.sh"
    if [[ ! -f "$profile_d" ]]; then
        echo 'export MOZ_ENABLE_WAYLAND=1' | sudo tee "$profile_d" > /dev/null
        echo "  [OK] Firefox Wayland forced via profile.d"
    else
        echo "  [OK] Firefox Wayland already forced"
    fi

    # Chrome/Chromium: Add flags for Wayland and PipeWire
    local chrome_flags_dir="$HOME/.config"
    mkdir -p "$chrome_flags_dir"

        for browser in "chrome" "chromium" "brave"; do
        local flags_file="${chrome_flags_dir}/${browser}-flags.conf"
        if [[ ! -f "$flags_file" ]]; then
            cat <<EOF > "$flags_file"
--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization
--ozone-platform-hint=auto
--enable-gpu-rasterization
--enable-zero-copy
--ignore-gpu-blocklist
EOF
            echo "  [OK] Added Wayland & Hardware Acceleration flags for $browser"
        else
            echo "  [OK] Flags for $browser already configured"
        fi
    done
}

optimize_dns() {
    echo ""
    echo "[+] Optimizing DNS resolution (systemd-resolved)..."
    
    local resolved_conf="/etc/systemd/resolved.conf.d/99-optimize.conf"
    sudo mkdir -p /etc/systemd/resolved.conf.d
    
    if [[ ! -f "$resolved_conf" ]]; then
        sudo tee "$resolved_conf" > /dev/null <<EOF
[Resolve]
Cache=yes
CacheFromLocalhost=no
LLMNR=no
MulticastDNS=resolve
EOF
        sudo systemctl restart systemd-resolved 2>/dev/null
        echo "  [OK] DNS caching enabled, LLMNR disabled (prevents timeouts)"
    else
        echo "  [OK] DNS already optimized"
    fi
}

optimize_time_sync() {
    echo ""
    echo "[+] Fixing hardware clock for Windows dual-boot compatibility..."
    
    # Windows uses Local Time for the hardware clock, Linux uses UTC.
    # This causes the clock to be wrong when switching OS.
    # Setting Linux to use Local Time fixes this common annoyance.
    timedatectl set-local-rtc 1 --adjust-system-clock 2>/dev/null || true
    echo "  [OK] Hardware clock set to Local Time (LocalRTC=1)"
}
