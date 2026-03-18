#!/usr/bin/env bash
set -euo pipefail

#  FedoraFlow — Intelligent system configuration script
#  Detects your system and applies the best configuration automatically.
#
#  Usage:
#    ./setup.sh              # Run interactive profile menu
#    ./setup.sh --profile X  # Run a specific profile (standard, dev, gaming, ultimate)
#    ./setup.sh --module X   # Run a specific module
#    ./setup.sh --restore    # Revert performance/power optimizations
#
#  Profiles: standard, dev, gaming, ultimate
#  Modules: sudo, repos, packages, flatpaks, nvidia, themes, extensions,
#           gnome, lockscreen, power, security, updates, optimize, backup,
#           dev, gaming, debloat, screen-sharing, maintenance, network,
#           hibernate, privacy, battery, printer, restore
#
#  Diagnostics:
#    ./setup.sh --check          # Run system health check

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
        dev)        setup_dev_env ;;
        gaming)     setup_gaming_env ;;
        debloat)        setup_debloat ;;
        screen-sharing) fix_screen_sharing ;;
        maintenance)    run_maintenance ;;
        network)        harden_network ;;
        hibernate)      configure_hibernate ;;
        privacy)        harden_privacy ;;
        battery)        configure_battery_threshold ;;
        printer)        setup_printer_scanner ;;
        healthcheck)    run_healthcheck ;;
        restore)        restore_system ;;
        *)
            err "Unknown module: $name"
            echo "Available: sudo, repos, packages, flatpaks, nvidia, themes,"
            echo "           extensions, gnome, lockscreen, power, security,"
            echo "           updates, optimize, backup, dev, gaming, debloat,"
            echo "           screen-sharing, maintenance, network, hibernate,"
            echo "           privacy, battery, printer, healthcheck, restore"
            return 1
            ;;
    esac
}

run_all() {
    local start_time=$SECONDS
    local profile_name="${1:-standard}"

    echo ""
    echo -e "${GREEN}${BOLD}Starting FedoraFlow Profile: ${profile_name^^}${NC}"
    echo ""

    echo -e "${BOLD}Phase 1/12 — System Basics${NC}"
    configure_sudo
    setup_repos

    echo ""
    echo -e "${BOLD}Phase 2/12 — Packages & Applications${NC}"
    install_packages
    install_flatpaks
    install_nvidia

    echo ""
    echo -e "${BOLD}Phase 3/12 — Desktop Environment${NC}"
    setup_themes
    install_extensions
    apply_gnome_settings
    configure_lockscreen_wallpaper_sync

    echo ""
    echo -e "${BOLD}Phase 4/12 — Performance Optimization${NC}"
    optimize_system

    echo ""
    echo -e "${BOLD}Phase 5/12 — Power Management${NC}"
    configure_power

    echo ""
    echo -e "${BOLD}Phase 6/12 — Security Hardening${NC}"
    configure_security

    echo ""
    echo -e "${BOLD}Phase 7/12 — System Updates${NC}"
    configure_updates

    echo ""
    echo -e "${BOLD}Phase 8/12 — System Backup & Snapshots${NC}"
    configure_backups

    echo ""
    echo -e "${BOLD}Phase 9/12 — Screen Sharing Fix${NC}"
    fix_screen_sharing

    echo ""
    echo -e "${BOLD}Phase 10/12 — Network Hardening${NC}"
    harden_network

    echo ""
    echo -e "${BOLD}Phase 11/12 — Laptop Optimizations${NC}"
    configure_hibernate
    configure_battery_threshold

    echo ""
    echo -e "${BOLD}Phase 12/12 — Printer & Scanner Support${NC}"
    setup_printer_scanner

    # Profile Additions
    if [[ "$profile_name" == "dev" ]] || [[ "$profile_name" == "ultimate" ]]; then
        setup_dev_env
    fi
    if [[ "$profile_name" == "gaming" ]] || [[ "$profile_name" == "ultimate" ]]; then
        setup_gaming_env
    fi
    if [[ "$profile_name" == "ultimate" ]]; then
        setup_debloat
        harden_privacy
    fi

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
    echo "    [x] Wayland Screen Sharing (xdg-desktop-portal + PipeWire)"
    echo "    [x] Network Hardening (WiFi power-save, MAC randomization, IPv6 privacy)"
    echo "    [x] Suspend-then-Hibernate (laptop battery saver)"
    echo "    [x] Battery Charge Threshold (80% limit for longevity)"
    echo "    [x] Printer & Scanner support (CUPS, SANE, IPP auto-discovery)"
    if [[ "$profile_name" == "dev" ]] || [[ "$profile_name" == "ultimate" ]]; then
        echo "    [x] Dev Environment (Podman, Toolbox, NVM, Zsh, Starship)"
    fi
    if [[ "$profile_name" == "gaming" ]] || [[ "$profile_name" == "ultimate" ]]; then
        echo "    [x] Gaming Environment (Steam, Lutris, Gamemode, Kernel tweaks)"
    fi
    if [[ "$profile_name" == "ultimate" ]]; then
        echo "    [x] Debloat & Privacy (telemetry, tracker blocking, Firefox hardening, DoH)"
    fi
    echo ""
    echo "  Recommended next steps:"
    echo "    1. Reboot the system for all changes to take effect"
    echo "    2. Log back in and open Extension Manager to fine-tune"
    echo "    3. Run './setup.sh --check' to verify system health"
    echo "    4. Run './setup.sh --module maintenance' for periodic cleanup"
    echo ""
    echo "  Log saved to: ${LOG_FILE}"
    echo ""
}

interactive_menu() {
    echo "Select what to set up:"
    echo ""
    echo -e "  ${BOLD}── One-Shot Profiles ──${NC}"
    echo "   1) Standard   (Performance, Power, Security, UI)"
    echo "   2) Developer  (Standard + Podman, Toolbox, NVM, Zsh)"
    echo "   3) Gamer      (Standard + Steam, Gamemode, Kernel Tweaks)"
    echo "   4) Ultimate   (Standard + Developer + Gamer + Debloat)"
    echo ""
    echo -e "  ${BOLD}── Individual Modules ──${NC}"
    echo "   5) Passwordless sudo"
    echo "   6) Repositories (RPM Fusion, Flathub, Chrome, Cursor, Terra)"
    echo "   7) System packages (categorized)"
    echo "   8) Flatpak applications"
    echo "   9) NVIDIA drivers"
    echo "  10) Themes & appearance"
    echo "  11) GNOME extensions"
    echo "  12) GNOME settings & tweaks"
    echo "  13) Lock screen wallpaper sync"
    echo "  14) System optimization (DNF, boot, kernel, network, I/O)"
    echo "  15) Power management (battery endurance)"
    echo "  16) Security hardening"
    echo "  17) System updates + auto-updates"
    echo "  18) Configure Btrfs Snapshots (Timeshift)"
    echo "  19) Wayland Screen Sharing Fix"
    echo "  20) Network Hardening (WiFi, MAC, IPv6)"
    echo "  21) Suspend-then-Hibernate (laptop)"
    echo "  22) Privacy Hardening (Firefox, DoH, trackers)"
    echo "  23) Battery Charge Threshold (80% limit)"
    echo "  24) Printer & Scanner Setup"
    echo ""
    echo -e "  ${BOLD}── Diagnostics & Maintenance ──${NC}"
    echo "  25) System Health Check"
    echo "  26) System Maintenance (cleanup)"
    echo "  27) Restore / Rollback optimizations"
    echo ""
    echo "   0) Exit"
    echo ""
    read -rp "Choose [0-27]: " choice

    case "$choice" in
        1)  run_all "standard" ;;
        2)  run_all "dev" ;;
        3)  run_all "gaming" ;;
        4)  run_all "ultimate" ;;
        5)  configure_sudo ;;
        6)  setup_repos ;;
        7)  install_packages ;;
        8)  install_flatpaks ;;
        9)  install_nvidia ;;
        10) setup_themes ;;
        11) install_extensions ;;
        12) apply_gnome_settings ;;
        13) configure_lockscreen_wallpaper_sync ;;
        14) optimize_system ;;
        15) configure_power ;;
        16) configure_security ;;
        17) configure_updates ;;
        18) configure_backups ;;
        19) fix_screen_sharing ;;
        20) harden_network ;;
        21) configure_hibernate ;;
        22) harden_privacy ;;
        23) configure_battery_threshold ;;
        24) setup_printer_scanner ;;
        25) run_healthcheck ;;
        26) run_maintenance ;;
        27) restore_system ;;
        0)  echo "Bye!"; exit 0 ;;
        *)  err "Invalid choice"; interactive_menu ;;
    esac
}

main() {
    header

    detect_system
    print_system_info

    require_fedora

    if [[ "${1:-}" == "--all" ]] || [[ "${1:-}" == "--profile" && "${2:-}" == "standard" ]]; then
        run_all "standard"
    elif [[ "${1:-}" == "--profile" && "${2:-}" == "dev" ]]; then
        run_all "dev"
    elif [[ "${1:-}" == "--profile" && "${2:-}" == "gaming" ]]; then
        run_all "gaming"
    elif [[ "${1:-}" == "--profile" && "${2:-}" == "ultimate" ]]; then
        run_all "ultimate"
    elif [[ "${1:-}" == "--check" ]]; then
        run_healthcheck
    elif [[ "${1:-}" == "--maintenance" ]]; then
        run_maintenance
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
