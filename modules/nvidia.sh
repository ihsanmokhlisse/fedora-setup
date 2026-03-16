#!/usr/bin/env bash
# GPU driver setup — detects GPU vendor and installs appropriate drivers

install_nvidia() {
    echo ""
    echo "━━━ GPU Driver Setup ━━━"

    case "$GPU_VENDOR" in
        nvidia)
            install_nvidia_drivers
            ;;
        amd)
            echo "[+] AMD GPU detected"
            echo "[OK] AMD GPUs use the open-source amdgpu driver (included in kernel)"
            if [[ "$PKG_MANAGER" == "dnf" ]]; then
                echo "     For Vulkan support, ensuring mesa-vulkan-drivers is installed..."
                sudo dnf install -y --skip-unavailable mesa-vulkan-drivers vulkan-loader 2>&1 | tail -2
            fi
            ;;
        intel)
            echo "[+] Intel GPU detected"
            echo "[OK] Intel GPUs use the open-source i915 driver (included in kernel)"
            if [[ "$PKG_MANAGER" == "dnf" ]]; then
                echo "     For hardware video acceleration..."
                sudo dnf install -y --skip-unavailable intel-media-driver libva-utils 2>&1 | tail -2
            fi
            ;;
        *)
            echo "[SKIP] No discrete GPU detected or GPU vendor unknown"
            echo "       System will use default kernel drivers"
            ;;
    esac
}

install_nvidia_drivers() {
    if [[ "$PKG_MANAGER" != "dnf" ]]; then
        echo "[SKIP] NVIDIA auto-install only supported on Fedora/DNF"
        return 0
    fi

    if rpm -q akmod-nvidia &>/dev/null; then
        echo "[OK] NVIDIA akmod driver already installed"
        return 0
    fi

    echo "[+] Detected NVIDIA GPU"
    echo "[+] Installing NVIDIA drivers via akmod..."

    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-libs

    if [[ "$IS_WAYLAND" == true ]]; then
        echo "[+] Enabling NVIDIA Wayland support..."
        sudo dnf install -y xorg-x11-drv-nvidia-cuda 2>/dev/null || true
    fi

    echo "[+] Waiting for kmod build (this can take a few minutes)..."
    sudo akmods --force 2>/dev/null || true

    echo "[OK] NVIDIA drivers installed. A reboot is required."
}
