#!/usr/bin/env bash
# System Health Check — diagnostics, SMART, battery, temps, services, security posture
# Run with: ./setup.sh --check

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_healthcheck() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "         FedoraFlow Health Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local score=0
    local max_score=0

    check_disk_health score max_score
    check_battery_health score max_score
    check_cpu_temps score max_score
    check_memory_pressure score max_score
    check_disk_usage score max_score
    check_failed_services score max_score
    check_security_posture score max_score
    check_update_status score max_score
    check_boot_time score max_score

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  Health Score: %d / %d" "$score" "$max_score"
    if [[ $max_score -gt 0 ]]; then
        local pct=$(( score * 100 / max_score ))
        if [[ $pct -ge 80 ]]; then
            printf "  (%d%% — Excellent)\n" "$pct"
        elif [[ $pct -ge 60 ]]; then
            printf "  (%d%% — Good)\n" "$pct"
        elif [[ $pct -ge 40 ]]; then
            printf "  (%d%% — Fair — attention needed)\n" "$pct"
        else
            printf "  (%d%% — Poor — action required)\n" "$pct"
        fi
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_disk_health() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Disk Health (SMART) ──"
    (( _max += 10 ))

    if ! command -v smartctl &>/dev/null; then
        echo "  [SKIP] smartmontools not installed"
        return
    fi

    local all_ok=true
    for disk in /dev/nvme0n1 /dev/sda /dev/sdb; do
        [[ -b "$disk" ]] || continue
        local status
        status=$(sudo smartctl -H "$disk" 2>/dev/null | grep -i "overall\|result")
        if echo "$status" | grep -qi "PASSED\|OK"; then
            echo "  [OK] $disk — SMART: PASSED"
        else
            echo "  [!!] $disk — SMART: FAILING"
            all_ok=false
        fi

        if [[ "$disk" == /dev/nvme* ]]; then
            local pct_used
            pct_used=$(sudo smartctl -A "$disk" 2>/dev/null | grep -i "Percentage Used" | awk '{print $NF}' | tr -d '%')
            if [[ -n "$pct_used" ]]; then
                echo "       NVMe wear: ${pct_used}% used"
                if [[ "$pct_used" -gt 80 ]]; then
                    echo "       [WARN] NVMe wearing out — consider replacement planning"
                fi
            fi
        fi
    done

    [[ "$all_ok" == true ]] && (( _score += 10 ))
}

check_battery_health() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Battery Health ──"

    if [[ "$IS_LAPTOP" != true ]]; then
        echo "  [N/A] Desktop — no battery"
        return
    fi

    (( _max += 10 ))

    for bat in /sys/class/power_supply/BAT*; do
        [[ -d "$bat" ]] || continue
        local name=$(basename "$bat")

        local design_full
        design_full=$(cat "${bat}/energy_full_design" 2>/dev/null || cat "${bat}/charge_full_design" 2>/dev/null || echo "0")
        local current_full
        current_full=$(cat "${bat}/energy_full" 2>/dev/null || cat "${bat}/charge_full" 2>/dev/null || echo "0")
        local status
        status=$(cat "${bat}/status" 2>/dev/null || echo "Unknown")
        local cycle_count
        cycle_count=$(cat "${bat}/cycle_count" 2>/dev/null || echo "N/A")

        if [[ "$design_full" -gt 0 ]] 2>/dev/null; then
            local health=$(( current_full * 100 / design_full ))
            echo "  $name: ${health}% health | Status: $status | Cycles: $cycle_count"

            if [[ "$health" -ge 70 ]]; then
                (( _score += 10 ))
            elif [[ "$health" -ge 50 ]]; then
                (( _score += 5 ))
                echo "  [WARN] Battery degraded — consider charge threshold (80%) to slow wear"
            else
                echo "  [!!] Battery heavily degraded — replacement recommended"
            fi
        else
            echo "  $name: Status: $status (capacity data unavailable)"
        fi
    done
}

check_cpu_temps() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── CPU Temperature ──"
    (( _max += 10 ))

    local temp_found=false
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [[ -f "$zone" ]] || continue
        local raw
        raw=$(cat "$zone" 2>/dev/null)
        [[ -z "$raw" ]] && continue

        local temp_c=$(( raw / 1000 ))
        local zone_type
        zone_type=$(cat "$(dirname "$zone")/type" 2>/dev/null || echo "unknown")

        if echo "$zone_type" | grep -qi "x86_pkg\|core\|cpu\|acpitz"; then
            echo "  $zone_type: ${temp_c}°C"
            temp_found=true

            if [[ "$temp_c" -lt 80 ]]; then
                (( _score += 10 ))
            elif [[ "$temp_c" -lt 95 ]]; then
                (( _score += 5 ))
                echo "  [WARN] CPU is warm — check fans and airflow"
            else
                echo "  [!!] CPU is overheating — thermal throttling likely"
            fi
            break
        fi
    done

    if [[ "$temp_found" == false ]]; then
        echo "  [SKIP] No CPU temperature sensor found"
        (( _score += 10 ))
    fi
}

check_memory_pressure() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Memory ──"
    (( _max += 10 ))

    local mem_total mem_avail pct_used
    mem_total=$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
    mem_avail=$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)
    if [[ "$mem_total" -gt 0 ]] 2>/dev/null; then
        pct_used=$(( (mem_total - mem_avail) * 100 / mem_total ))
    else
        pct_used=0
    fi

    echo "  RAM: ${mem_avail}MB available / ${mem_total}MB total (${pct_used}% used)"

    if command -v zramctl &>/dev/null; then
        local zram_info
        zram_info=$(zramctl --output NAME,DISKSIZE,DATA,COMPR,ALGORITHM --noheadings 2>/dev/null | head -1)
        [[ -n "$zram_info" ]] && echo "  ZRAM: $zram_info"
    fi

    if [[ $pct_used -lt 80 ]]; then
        (( _score += 10 ))
    elif [[ $pct_used -lt 90 ]]; then
        (( _score += 5 ))
        echo "  [WARN] Memory pressure — close unused apps"
    else
        echo "  [!!] Memory critically low — OOM likely"
    fi
}

check_disk_usage() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Disk Usage ──"
    (( _max += 10 ))

    local root_pct
    root_pct=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
    local root_avail
    root_avail=$(df -h / | awk 'NR==2 {print $4}')

    echo "  / : ${root_pct}% used (${root_avail} free)"

    if [[ -d /home ]] && df /home | grep -v "^Filesystem" | grep -qv "$(df / | awk 'NR==2{print $1}')"; then
        local home_pct
        home_pct=$(df /home | awk 'NR==2 {gsub(/%/,""); print $5}')
        local home_avail
        home_avail=$(df -h /home | awk 'NR==2 {print $4}')
        echo "  /home: ${home_pct}% used (${home_avail} free)"
    fi

    if [[ "$root_pct" -lt 80 ]]; then
        (( _score += 10 ))
    elif [[ "$root_pct" -lt 90 ]]; then
        (( _score += 5 ))
        echo "  [WARN] Disk getting full — run './setup.sh --module maintenance' to clean up"
    else
        echo "  [!!] Disk critically full — immediate cleanup needed"
    fi
}

check_failed_services() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Failed Services ──"
    (( _max += 10 ))

    local failed
    failed=$(systemctl --failed --no-legend --no-pager 2>/dev/null | grep -v "^$")
    local count=0
    if [[ -n "$failed" ]]; then
        count=$(echo "$failed" | wc -l)
    fi

    if [[ "$count" -eq 0 ]]; then
        echo "  [OK] No failed services"
        (( _score += 10 ))
    else
        echo "  [!!] $count failed service(s):"
        echo "$failed" | head -5 | while read -r line; do
            echo "       $line"
        done
        echo "  [FIX] Run: systemctl --failed"
    fi
}

check_security_posture() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Security Posture ──"
    (( _max += 10 ))

    local sec_score=0
    local sec_max=5

    if getenforce 2>/dev/null | grep -q "Enforcing"; then
        echo "  [OK] SELinux: Enforcing"
        (( sec_score++ ))
    else
        echo "  [!!] SELinux: NOT enforcing"
    fi

    if systemctl is-active firewalld &>/dev/null; then
        local zone
        zone=$(firewall-cmd --get-default-zone 2>/dev/null)
        echo "  [OK] Firewall: active (zone: $zone)"
        (( sec_score++ ))
    else
        echo "  [!!] Firewall: INACTIVE"
    fi

    if systemctl is-active fail2ban &>/dev/null; then
        echo "  [OK] Fail2ban: active"
        (( sec_score++ ))
    else
        echo "  [--] Fail2ban: not running"
    fi

    if [[ -f /etc/ssh/sshd_config.d/99-hardened.conf ]]; then
        echo "  [OK] SSH: hardened"
        (( sec_score++ ))
    else
        echo "  [--] SSH: default config"
    fi

    local auto_updates
    if systemctl is-enabled dnf-automatic.timer &>/dev/null 2>&1; then
        echo "  [OK] Auto-updates: enabled"
        (( sec_score++ ))
    else
        echo "  [--] Auto-updates: not configured"
    fi

    (( _score += sec_score * 10 / sec_max ))
}

check_update_status() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Update Status ──"
    (( _max += 10 ))

    local update_output
    update_output=$(dnf check-update --quiet 2>/dev/null | grep -c "^\S" || true)
    local updates=${update_output:-0}
    updates=$(echo "$updates" | tr -d '[:space:]')

    if [[ "$updates" -eq 0 ]] 2>/dev/null; then
        echo "  [OK] System is up to date"
        (( _score += 10 ))
    elif [[ "$updates" -lt 20 ]] 2>/dev/null; then
        echo "  [--] $updates update(s) available"
        (( _score += 5 ))
    else
        echo "  [!!] $updates update(s) pending — run: sudo dnf upgrade"
    fi
}

check_boot_time() {
    local -n _score=$1
    local -n _max=$2
    echo ""
    echo "── Boot Performance ──"
    (( _max += 10 ))

    local boot_time
    boot_time=$(systemd-analyze 2>/dev/null | head -1)
    echo "  $boot_time"

    local total_sec
    total_sec=$(systemd-analyze 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+s$' | tr -d 's')

    if [[ -n "$total_sec" ]]; then
        local total_int=${total_sec%.*}
        if [[ "$total_int" -lt 15 ]]; then
            (( _score += 10 ))
            echo "  [OK] Boot time is excellent"
        elif [[ "$total_int" -lt 30 ]]; then
            (( _score += 7 ))
            echo "  [OK] Boot time is acceptable"
        elif [[ "$total_int" -lt 60 ]]; then
            (( _score += 3 ))
            echo "  [WARN] Boot is slow — check: systemd-analyze blame"
        else
            echo "  [!!] Boot is very slow — investigate with: systemd-analyze critical-chain"
        fi
    fi
}
