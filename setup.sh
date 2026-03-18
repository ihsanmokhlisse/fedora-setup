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
#           dev, gaming, debloat, restore

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
        debloat)    setup_debloat ;;
        restore)    restore_system ;;
        *)
            err "Unknown module: $name"
            echo "Available: sudo, repos, packages, flatpaks, nvidia, themes,"
            echo "           extensions, gnome, lockscreen, power, security,"
            echo "           updates, optimize, backup, dev, gaming, debloat, restore"
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

    echo -e "${BOLD}Phase 1/8 — System Basics${NC}"
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

    # Profile Additions
    if [[ "$profile_name" == "dev" ]] || [[ "$profile_name" == "ultimate" ]]; then
        setup_dev_env
    fi
    if [[ "$profile_name" == "gaming" ]] || [[ "$profile_name" == "ultimate" ]]; then
        setup_gaming_env
    fi
    if [[ "$profile_name" == "ultimate" ]]; then
        setup_debloat
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
    if [[ "$profile_name" == "dev" ]] || [[ "$profile_name" == "ultimate" ]]; then
        echo "    [x] Dev Environment (Podman, Toolbox, NVM, Zsh, Starship)"
    fi
    if [[ "$profile_name" == "gaming" ]] || [[ "$profile_name" == "ultimate" ]]; then
        echo "    [x] Gaming Environment (Steam, Lutris, Gamemode, Kernel tweaks)"
    fi
    if [[ "$profile_name" == "ultimate" ]]; then
        echo "    [x] Debloat & Privacy (Removed telemetry and bloatware)"
    fi
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
    echo ""
    echo -e "  ${BOLD}── Maintenance ──${NC}"
    echo "  19) Restore / Rollback optimizations"
    echo ""
    echo "   0) Exit"
    echo ""
    read -rp "Choose [0-19]: " choice

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
        19) restore_system ;;
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
