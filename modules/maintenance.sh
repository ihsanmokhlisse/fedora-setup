#!/usr/bin/env bash
# System Maintenance — cleanup old kernels, orphans, cache, journal, Flatpak runtimes
# Can be run periodically or as a one-shot cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_maintenance() {
    echo ""
    echo "━━━ System Maintenance & Cleanup ━━━"

    cleanup_old_kernels
    cleanup_orphaned_packages
    cleanup_dnf_cache
    cleanup_journal
    cleanup_flatpak
    cleanup_tmp
    cleanup_user_cache

    echo ""
    echo "[OK] System maintenance complete"
}

cleanup_old_kernels() {
    echo ""
    echo "[+] Removing old kernels (keeping latest 2)..."

    local kernel_count
    kernel_count=$(rpm -q kernel --queryformat '%{installtime} %{name}-%{version}-%{release}.%{arch}\n' 2>/dev/null | wc -l)

    if [[ "$kernel_count" -gt 2 ]]; then
        sudo dnf remove -y --oldinstallonly --setopt installonly_limit=2 2>&1 | tail -3
        echo "  [OK] Old kernels removed (kept latest 2)"
    else
        echo "  [OK] Only $kernel_count kernel(s) installed — nothing to remove"
    fi
}

cleanup_orphaned_packages() {
    echo ""
    echo "[+] Checking for orphaned packages..."

    local orphans
    orphans=$(dnf repoquery --extras --quiet 2>/dev/null | head -20)

    if [[ -n "$orphans" ]]; then
        local count
        count=$(echo "$orphans" | wc -l)
        echo "  [!] Found $count orphaned package(s)"
        echo "  [NOTE] Review with: dnf repoquery --extras"
        echo "  [NOTE] Remove with: sudo dnf remove \$(dnf repoquery --extras --quiet)"
    else
        echo "  [OK] No orphaned packages found"
    fi
}

cleanup_dnf_cache() {
    echo ""
    echo "[+] Cleaning DNF package cache..."

    local cache_size
    cache_size=$(du -sh /var/cache/libdnf5 2>/dev/null | awk '{print $1}')
    [[ -z "$cache_size" ]] && cache_size=$(du -sh /var/cache/dnf 2>/dev/null | awk '{print $1}')

    sudo dnf clean all -q 2>/dev/null
    echo "  [OK] DNF cache cleaned (was ${cache_size:-unknown})"
}

cleanup_journal() {
    echo ""
    echo "[+] Vacuuming systemd journal..."

    local journal_size
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]')

    sudo journalctl --vacuum-time=7d --vacuum-size=100M -q 2>/dev/null
    echo "  [OK] Journal vacuumed to 7 days / 100MB max (was ${journal_size:-unknown})"
}

cleanup_flatpak() {
    echo ""
    echo "[+] Removing unused Flatpak runtimes..."

    local unused
    unused=$(flatpak uninstall --unused 2>/dev/null | grep -c "uninstalling" || echo "0")

    flatpak uninstall --unused -y 2>/dev/null || true

    flatpak repair --user 2>/dev/null || true
    echo "  [OK] Unused Flatpak runtimes cleaned"
}

cleanup_tmp() {
    echo ""
    echo "[+] Cleaning temporary files..."

    local tmp_size
    tmp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}')

    sudo systemd-tmpfiles --clean 2>/dev/null || true

    if [[ -d "$HOME/.cache/thumbnails" ]]; then
        find "$HOME/.cache/thumbnails" -type f -atime +30 -delete 2>/dev/null || true
        echo "  [OK] Old thumbnails (>30 days) cleaned"
    fi

    echo "  [OK] Temp files cleaned (was ${tmp_size:-unknown})"
}

cleanup_user_cache() {
    echo ""
    echo "[+] Cleaning user-level caches..."

    local dirs_to_clean=(
        "$HOME/.cache/pip"
        "$HOME/.cache/yarn"
        "$HOME/.cache/pnpm"
        "$HOME/.npm/_cacache"
        "$HOME/.cache/mesa_shader_cache"
        "$HOME/.cache/fontconfig"
    )

    local total_freed=0
    for dir in "${dirs_to_clean[@]}"; do
        if [[ -d "$dir" ]]; then
            local size
            size=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
            rm -rf "$dir" 2>/dev/null
            total_freed=$(( total_freed + ${size:-0} ))
        fi
    done

    if [[ $total_freed -gt 0 ]]; then
        local freed_mb=$(( total_freed / 1024 / 1024 ))
        echo "  [OK] Cleaned ${freed_mb}MB from user caches"
    else
        echo "  [OK] User caches already clean"
    fi
}

setup_maintenance_timer() {
    echo ""
    echo "[+] Setting up weekly maintenance timer..."

    local service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"

    if [[ ! -f "${service_dir}/fedoraflow-maintenance.service" ]]; then
        cat > "${service_dir}/fedoraflow-maintenance.service" <<EOF
[Unit]
Description=FedoraFlow Weekly Maintenance

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sudo journalctl --vacuum-time=7d --vacuum-size=100M -q; flatpak uninstall --unused -y; find \$HOME/.cache/thumbnails -type f -atime +30 -delete 2>/dev/null; sudo dnf clean all -q'
EOF

        cat > "${service_dir}/fedoraflow-maintenance.timer" <<EOF
[Unit]
Description=FedoraFlow Weekly Maintenance Timer

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
EOF

        systemctl --user daemon-reload
        systemctl --user enable --now fedoraflow-maintenance.timer 2>/dev/null
        echo "  [OK] Weekly maintenance timer enabled"
    else
        echo "  [OK] Maintenance timer already configured"
    fi
}
