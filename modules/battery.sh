#!/usr/bin/env bash
# Battery Charge Threshold — limits max charge to extend battery lifespan
# Supports ThinkPad, ASUS, Framework, and generic sysfs interfaces

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

configure_battery_threshold() {
    echo ""
    echo "━━━ Battery Charge Threshold ━━━"

    if [[ "$IS_LAPTOP" != true ]]; then
        echo "[SKIP] Not a laptop — no battery to configure"
        return 0
    fi

    local vendor
    vendor=$(detect_laptop_vendor)

    case "$vendor" in
        thinkpad)  configure_thinkpad_threshold ;;
        asus)      configure_asus_threshold ;;
        framework) configure_framework_threshold ;;
        *)         configure_generic_threshold ;;
    esac

    echo ""
    echo "[OK] Battery charge threshold configured"
}

detect_laptop_vendor() {
    local sys_vendor
    sys_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]')
    local product
    product=$(cat /sys/class/dmi/id/product_family 2>/dev/null | tr '[:upper:]' '[:lower:]')

    if echo "$sys_vendor $product" | grep -qi "thinkpad\|lenovo"; then
        if [[ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]]; then
            echo "thinkpad"
            return
        fi
    fi

    if echo "$sys_vendor" | grep -qi "asus"; then
        if [[ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]] || \
           [[ -f /sys/devices/platform/asus-nb-wmi/charge_control_end_threshold ]]; then
            echo "asus"
            return
        fi
    fi

    if echo "$sys_vendor $product" | grep -qi "framework"; then
        echo "framework"
        return
    fi

    if [[ -f /sys/class/power_supply/BAT0/charge_control_end_threshold ]]; then
        echo "generic"
        return
    fi

    echo "unsupported"
}

configure_thinkpad_threshold() {
    echo ""
    echo "[+] Configuring ThinkPad battery charge threshold..."

    local threshold_file="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    local start_file="/sys/class/power_supply/BAT0/charge_control_start_threshold"

    local current
    current=$(cat "$threshold_file" 2>/dev/null)
    if [[ "$current" == "80" ]]; then
        echo "  [OK] Already set to 80%"
        return
    fi

    echo 80 | sudo tee "$threshold_file" > /dev/null 2>&1
    if [[ -f "$start_file" ]]; then
        echo 75 | sudo tee "$start_file" > /dev/null 2>&1
    fi

    persist_threshold "thinkpad"
    echo "  [OK] ThinkPad: Charge stops at 80%, resumes at 75%"
    echo "  [NOTE] This extends battery lifespan by ~2x"
}

configure_asus_threshold() {
    echo ""
    echo "[+] Configuring ASUS battery charge threshold..."

    local threshold_file="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    if [[ ! -f "$threshold_file" ]]; then
        threshold_file="/sys/devices/platform/asus-nb-wmi/charge_control_end_threshold"
    fi

    local current
    current=$(cat "$threshold_file" 2>/dev/null)
    if [[ "$current" == "80" ]]; then
        echo "  [OK] Already set to 80%"
        return
    fi

    echo 80 | sudo tee "$threshold_file" > /dev/null 2>&1

    persist_threshold "asus"
    echo "  [OK] ASUS: Charge limited to 80%"
}

configure_framework_threshold() {
    echo ""
    echo "[+] Configuring Framework battery charge threshold..."

    local threshold_file="/sys/class/power_supply/BAT1/charge_control_end_threshold"
    if [[ ! -f "$threshold_file" ]]; then
        threshold_file="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    fi

    if [[ -f "$threshold_file" ]]; then
        echo 80 | sudo tee "$threshold_file" > /dev/null 2>&1
        persist_threshold "framework"
        echo "  [OK] Framework: Charge limited to 80%"
    else
        echo "  [WARN] Framework battery threshold sysfs not found"
        echo "         Update your EC firmware or use 'fw-ectool'"
    fi
}

configure_generic_threshold() {
    echo ""
    echo "[+] Attempting generic battery charge threshold..."

    local threshold_file="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    if [[ -f "$threshold_file" ]]; then
        local current
        current=$(cat "$threshold_file" 2>/dev/null)
        if [[ "$current" == "80" ]]; then
            echo "  [OK] Already set to 80%"
            return
        fi

        echo 80 | sudo tee "$threshold_file" > /dev/null 2>&1 && {
            persist_threshold "generic"
            echo "  [OK] Charge limited to 80%"
            return
        }
    fi

    echo "  [SKIP] Battery charge threshold not supported on this hardware"
    echo "         Your laptop vendor may not expose sysfs charge control."
    echo "         Check vendor-specific tools (e.g., tlp, power-profiles-daemon)"
}

persist_threshold() {
    local vendor="$1"

    local udev_rule="/etc/udev/rules.d/99-battery-threshold.rules"
    if [[ -f "$udev_rule" ]]; then
        return
    fi

    case "$vendor" in
        thinkpad)
            sudo tee "$udev_rule" > /dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="80", ATTR{charge_control_start_threshold}="75"
EOF
            ;;
        asus)
            if [[ -f /sys/devices/platform/asus-nb-wmi/charge_control_end_threshold ]]; then
                sudo tee "$udev_rule" > /dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", RUN+="/bin/bash -c 'echo 80 > /sys/devices/platform/asus-nb-wmi/charge_control_end_threshold'"
EOF
            else
                sudo tee "$udev_rule" > /dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="80"
EOF
            fi
            ;;
        framework)
            local bat="BAT0"
            [[ -f /sys/class/power_supply/BAT1/charge_control_end_threshold ]] && bat="BAT1"
            sudo tee "$udev_rule" > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="$bat", ATTR{charge_control_end_threshold}="80"
EOF
            ;;
        generic)
            sudo tee "$udev_rule" > /dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}="80"
EOF
            ;;
    esac

    sudo udevadm control --reload-rules 2>/dev/null
    echo "  [OK] Threshold persisted via udev (survives reboot)"
}
