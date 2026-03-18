#!/usr/bin/env bash
set -euo pipefail

#  FedoraFlow — Intelligent system configuration script
#  Detects your system and applies the best configuration automatically.
#
#  Usage:
#    ./setup.sh              # Run everything (interactive)
#    ./setup.sh --all        # Run everything (non-interactive)
#    ./setup.sh --module X   # Run a specific module
#    ./setup.sh --restore    # Revert performance/power optimizations
#
#  Modules: sudo, repos, packages, flatpaks, nvidia, themes, extensions,
#           gnome, lockscreen, power, security, updates, optimize, backup, restore

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }
header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
    echo -e "${CYAN}${BOLD}║              FedoraFlow                     ║${NC}"
    echo -e "${CYAN}${BOLD}║        github.com/coldarianzefra/fedora-setup              ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
    echo -e "${CYAN}${BOLD}║  Packages • Extensions • Themes • Power • Security • Perf ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Source all modules
for module in "${SCRIPT_DIR}"/modules/*.sh; do
    source "$module"
done

run_module() {
    local name="$1"
    case "$name" in
        sudo)       configure_sudo ;;
        repos)      setup_repos ;;
        packages)   install_packages ;;
        flatpaks)   install_flatpaks ;;
        nvidia)     install_nvidia ;;
        themes)     setup_themes ;;
        extensions) install_extensions ;;
        gnome)      apply_gnome_settings ;;
        lockscreen) configure_lockscreen_wallpaper_sync ;;
        power)      configure_power ;;
        security)   configure_security ;;
        updates)    configure_updates ;;
        optimize)   optimize_system ;;
        backup)     configure_backups ;;
        restore)    restore_system ;;
        *)
            err "Unknown module: $name"
            echo "Available: sudo, repos, packages, flatpaks, nvidia, themes,"
            echo "           extensions, gnome, lockscreen, power, security,"
            echo "           updates, optimize, backup, restore"
            return 1
            ;;
    esac
}

run_all() {
    local start_time=$SECONDS

    echo ""
    echo -e "${BOLD}Phase 1/7 — System Basics${NC}"
    configure_sudo
    setup_repos

    echo ""
    echo -e "${BOLD}Phase 2/7 — Packages & Applications${NC}"
    install_packages
    install_flatpaks
    install_nvidia

    echo ""
    echo -e "${BOLD}Phase 3/7 — Desktop Environment${NC}"
    setup_themes
    install_extensions
    apply_gnome_settings
    configure_lockscreen_wallpaper_sync

    echo ""
    echo -e "${BOLD}Phase 4/7 — Performance Optimization${NC}"
    optimize_system

    echo ""
    echo -e "${BOLD}Phase 5/7 — Power Management${NC}"
    configure_power

    echo ""
    echo -e "${BOLD}Phase 6/7 — Security Hardening${NC}"
    configure_security

    echo ""
    echo -e "${BOLD}Phase 7/8 — System Updates${NC}"
    configure_updates

    echo ""
    echo -e "${BOLD}Phase 8/8 — System Backup & Snapshots${NC}"
    configure_backups

    local elapsed=$(( SECONDS - start_time ))
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                           ║${NC}"
    printf "${GREEN}${BOLD}║              Setup complete in %-4ss                       ║${NC}\n" "$elapsed"
    echo -e "${GREEN}${BOLD}║                                                           ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  What was configured:"
    echo "    [x] Passwordless sudo"
    echo "    [x] Repositories (RPM Fusion, Flathub, Chrome, Cursor, Terra)"
    echo "    [x] System packages (categorized by purpose)"
    echo "    [x] Flatpak applications"
    echo "    [x] GPU drivers (if NVIDIA detected)"
    echo "    [x] Themes, icons, fonts, appearance"
    echo "    [x] GNOME extensions (16 extensions)"
    echo "    [x] Desktop settings (tap-to-click, fractional scaling, lock screen, Nautilus tweaks)"
    echo "    [x] Performance (DNF, boot, kernel, network, I/O, memory, DNS, Time Sync)"
    echo "    [x] Power management (tuned + NVIDIA suspend + GNOME)"
    echo "    [x] Security (firewall, kernel, SELinux, fail2ban, SSH)"
    echo "    [x] Auto-updates (DNF security, Flatpak, firmware)"
    echo "    [x] Btrfs Snapshots (Timeshift + GRUB integration)"
    echo ""
    echo "  Recommended next steps:"
    echo "    1. Reboot the system for all changes to take effect"
    echo "    2. Log back in and open Extension Manager to fine-tune"
    echo "    3. Run 'tuned-adm active' to verify power profile"
    echo "    4. Run 'systemd-analyze' to check improved boot time"
    echo ""
    echo "  Log saved to: ${LOG_FILE}"
    echo ""
}

interactive_menu() {
    echo "Select what to set up:"
    echo ""
    echo -e "  ${BOLD}── Full Setup ──${NC}"
    echo "   1) Everything (recommended for fresh install)"
    echo ""
    echo -e "  ${BOLD}── System ──${NC}"
    echo "   2) Passwordless sudo"
    echo "   3) Repositories (RPM Fusion, Flathub, Chrome, Cursor, Terra)"
    echo "   4) System packages (categorized)"
    echo "   5) Flatpak applications"
    echo "   6) NVIDIA drivers"
    echo ""
    echo -e "  ${BOLD}── Desktop ──${NC}"
    echo "   7) Themes & appearance"
    echo "   8) GNOME extensions"
    echo "   9) GNOME settings & tweaks"
    echo "  10) Lock screen wallpaper sync"
    echo ""
    echo -e "  ${BOLD}── Performance ──${NC}"
    echo "  11) System optimization (DNF, boot, kernel, network, I/O)"
    echo ""
    echo -e "  ${BOLD}── Power & Security ──${NC}"
    echo "  12) Power management (battery endurance)"
    echo "  13) Security hardening"
    echo "  14) System updates + auto-updates"
    echo "  15) Configure Btrfs Snapshots (Timeshift)"
    echo ""
    echo -e "  ${BOLD}── Maintenance ──${NC}"
    echo "  16) Restore / Rollback optimizations"
    echo ""
    echo "   0) Exit"
    echo ""
    read -rp "Choose [0-16]: " choice

    case "$choice" in
        1)  run_all ;;
        2)  configure_sudo ;;
        3)  setup_repos ;;
        4)  install_packages ;;
        5)  install_flatpaks ;;
        6)  install_nvidia ;;
        7)  setup_themes ;;
        8)  install_extensions ;;
        9)  apply_gnome_settings ;;
        10) configure_lockscreen_wallpaper_sync ;;
        11) optimize_system ;;
        12) configure_power ;;
        13) configure_security ;;
        14) configure_updates ;;
        15) configure_backups ;;
        16) restore_system ;;
        0)  echo "Bye!"; exit 0 ;;
        *)  err "Invalid choice"; interactive_menu ;;
    esac
}

main() {
    header

    detect_system
    print_system_info

    require_fedora

    if [[ "${1:-}" == "--all" ]]; then
        run_all
    elif [[ "${1:-}" == "--restore" ]]; then
        restore_system
    elif [[ "${1:-}" == "--module" ]] && [[ -n "${2:-}" ]]; then
        run_module "$2"
    elif [[ -n "${1:-}" ]] && [[ "${1:-}" != "--"* ]]; then
        run_module "$1"
    else
        interactive_menu
    fi
}

main "$@" 2>&1 | tee -a "$LOG_FILE"
