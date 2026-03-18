# FedoraFlow

An intelligent, all-in-one setup script that transforms a fresh Fedora install into the most optimized, powerful, and secure GNOME desktop possible — packages, extensions, themes, performance tuning, power management, security hardening, and auto-updates, all in one command.

## Quick Start

```bash
git clone https://github.com/ihsanmokhlisse/fedora-setup.git
cd fedora-setup
chmod +x setup.sh
./setup.sh
```

## Profiles

FedoraFlow now uses **Profiles**. Every profile includes the core performance, power, and security optimizations, but adds specific tools for your workflow.

* **Standard** (`./setup.sh --profile standard`): The baseline. Performance, security, battery life, and UI tweaks.
* **Developer** (`./setup.sh --profile dev`): Standard + Podman, Toolbox, NVM, Zsh, and Starship prompt.
* **Gamer** (`./setup.sh --profile gaming`): Standard + Steam, Lutris, Gamemode, and Kernel `max_map_count` tweaks.
* **Ultimate** (`./setup.sh --profile ultimate`): Standard + Dev + Gaming + Debloat (removes telemetry and GNOME bloatware).

## Usage Scenarios

FedoraFlow is highly modular. You don't have to run the whole suite if you only want specific improvements.

### Scenario 1: The Fresh Install (Standard)
You just installed Fedora and want everything set up perfectly—codecs, drivers, themes, and performance.
* **Command:** `./setup.sh` -> Choose Option `1` (Standard)

### Scenario 2: The Developer Workspace
You want the essential development tools, Podman (rootless), Toolbox (isolated dev environments), NVM, Zsh, and increased file descriptor limits so your IDE doesn't crash watching large projects.
* **Command:** `./setup.sh --profile dev`

### Scenario 3: The Linux Gamer
You want Steam, Lutris, Gamemode, and the crucial `vm.max_map_count` kernel tweak so heavy games like Cyberpunk 2077 don't crash.
* **Command:** `./setup.sh --profile gaming`

### Scenario 4: The Battery Saver (Laptop Users)
You love your current setup, but your laptop battery drains too fast. You only want the power optimizations (NVIDIA deep sleep, tuned profiles, charge thresholds).
* **Command:** `./setup.sh --module power`

### Scenario 5: The Performance Junkie
Your system feels a bit sluggish. You want faster DNF downloads, optimized disk I/O, BBR network congestion control, and faster boot times.
* **Command:** `./setup.sh --module optimize`

### Scenario 6: Safe Revert
You tried the optimizations, but a specific kernel parameter or power setting is causing issues with your specific hardware.
* **Command:** `./setup.sh --restore`

## What It Does

### Phase 1 — System Basics
| Module | Description |
|--------|-------------|
| **sudo** | Passwordless sudo for the current user |
| **repos** | RPM Fusion, Flathub, Terra, Chrome, Cursor, PyCharm |

### Phase 2 — Packages & Applications
| Module | Description |
|--------|-------------|
| **packages** | Categorized system packages (dev, office, media, gaming...) |
| **flatpaks** | Flatpak apps (Extension Manager, Gear Lever) |
| **nvidia** | Auto-detects NVIDIA GPU and installs akmod drivers |

### Phase 3 — Desktop Environment
| Module | Description |
|--------|-------------|
| **themes** | GTK theme, icons, cursor, fonts, Microsoft Core Fonts |
| **extensions** | 16 GNOME Shell extensions |
| **gnome** | Desktop settings (dock, blur, keybindings, favorites, Nautilus tweaks) |
| **lockscreen** | Wallpaper sync + BingWallpaper auto-sync |

### Phase 4 — Performance Optimization
| Module | Description |
|--------|-------------|
| **optimize** | DNF speed, boot time, kernel tuning, network (BBR), I/O scheduler, ZRAM (100% size, zstd), services cleanup, browser hardware acceleration (Wayland/PipeWire/VA-API), DNS caching, Dual-Boot time sync |

### Phase 5 — Power Management
| Module | Description |
|--------|-------------|
| **power** | Custom tuned profile, NVIDIA GPU suspend, kernel power params, GNOME power settings, battery charge thresholds |

### Phase 6 — Security Hardening
| Module | Description |
|--------|-------------|
| **security** | Firewall hardening, kernel hardening, SELinux, fail2ban, SSH hardening, USB restrictions |

### Phase 7 — System Updates
| Module | Description |
|--------|-------------|
| **updates** | DNF system update, firmware update, Flatpak update, auto-update timers |
| **backup** | Timeshift Btrfs snapshots, grub-btrfs integration, pre-update snapshots |

## System Detection

The script auto-detects and adapts to:

- **OS** — Fedora version (adapts repo URLs)
- **GNOME Shell** — version-compatible extensions
- **GPU** — NVIDIA / AMD / Intel (correct drivers + power management)
- **Wayland** — NVIDIA Wayland adjustments
- **Laptop vs Desktop** — battery threshold + power tuning
- **Architecture** — x86_64 / aarch64
- **Package Manager** — DNF / APT / Pacman

## Package Categories

| Category | Packages |
|----------|----------|
| **System Utilities** | htop, nvtop, btop, jq, tree, lsof, smartmontools |
| **Terminal & Shell** | vim, nano, tmux, bash-completion |
| **Development — Compilers** | git, gcc, g++, make, cmake, bison |
| **Development — Languages** | python3, pip |
| **Development — IDEs** | Cursor IDE |
| **Office & Productivity** | LibreOffice Writer, Calc, Impress |
| **Web Browsers** | Firefox (Chrome repo available) |
| **Multimedia** | ffmpeg, full PipeWire stack |
| **Gaming** | Lutris, Bottles, GameMode, MangoHud, Wine |
| **Virtualization** | Podman, GNOME Boxes |
| **Networking** | Synergy, OpenSSH |
| **System Management** | GParted, Timeshift, Baobab |
| **Fonts** | Source Code Pro, Comfortaa, Adwaita |
| **Hardware** | ALSA firmware |

Uncomment lines in `configs/packages.list` to enable optional packages (GIMP, Node.js, Docker, etc.).

## Repositories Configured

| Repository | What It Provides |
|------------|-----------------|
| **RPM Fusion Free** | ffmpeg, multimedia codecs |
| **RPM Fusion Nonfree** | NVIDIA drivers, Steam |
| **Terra** | Extra community packages |
| **Google Chrome** | google-chrome-stable |
| **Cursor IDE** | Cursor AI editor |
| **Copr: PyCharm** | PyCharm IDE |
| **Copr: python-validity** | Fingerprint reader support |
| **Flathub** | Flatpak applications |

## Performance Optimization

Makes Fedora as fast and responsive as possible:

| Optimization | Before | After | Impact |
|-------------|--------|-------|--------|
| **DNF parallel downloads** | 1 (sequential) | 10 parallel + fastest mirror | 3-5x faster installs |
| **Boot time** | ~1min 37s | ~30s | GRUB 1s, synergy deferred |
| **TCP congestion** | cubic | BBR (Google) | Better network throughput |
| **TCP Fast Open** | Client only | Client + server | Faster connections |
| **Network buffers** | 4MB | 16MB | Higher throughput |
| **NVMe read-ahead** | 128KB | 2048KB | Faster sequential reads |
| **I/O scheduler** | Auto | none (NVMe), BFQ (HDD) | Optimal per disk type |
| **inotify watchers** | 8192 | 524288 | No more IDE watch limits |
| **File descriptors** | 1024 | 65536 | No more "too many open files" |
| **earlyoom** | Not installed | Active | Prevents OOM freezes |
| **Btrfs mount** | relatime | noatime | Fewer unnecessary writes |
| **Journal** | Uncapped | 100MB / 1 week | Saves disk space |
| **Core dumps** | Unlimited | Disabled | Saves disk space |
| **Unnecessary services** | Running | Masked | Less CPU/memory overhead |

## Power Management

Designed for **MacBook Pro-level battery endurance**:

| Setting | Value | Impact |
|---------|-------|--------|
| Custom tuned profile | `fedora-endurance` | Balanced power/performance |
| NVIDIA GPU runtime PM | D3cold suspend | **Saves 5-15W** when GPU idle |
| NMI watchdog | Disabled | **Saves ~1W** |
| PCIe ASPM | powersupersave | Deep power states |
| Laptop mode | Enabled | Batches disk writes |
| Audio power save | Enabled | Codec sleeps after 1s |
| USB autosuspend | Enabled | USB devices sleep |
| Screen dim on idle | After 10 min | Reduces display power |
| Suspend on AC | Never | Laptop stays on while plugged in |
| Suspend on battery | After 30 min | Preserves battery |
| Low battery | Auto power-saver | Extends remaining time |
| Charge threshold | 75-80% | Maximizes battery lifespan |
| Battery % in top bar | Shown | Always visible |

## Security Hardening

Beginner-friendly but thorough:

| Protection | What It Does |
|-----------|-------------|
| **Firewall** | Switches from permissive FedoraWorkstation to tight 'home' zone |
| **Kernel hardening** | Hides kernel pointers, restricts ptrace, blocks ICMP redirects, SYN flood protection, ASLR max |
| **SELinux** | Ensures enforcing mode |
| **fail2ban** | Blocks SSH brute-force (3 attempts = 3h ban) |
| **SSH hardening** | Root login disabled, key-only auth, 3 max attempts |
| **USB protection** | Blocks auto-mount of USB storage on locked screen |
| **Auto-updates** | DNF security updates daily, Flatpak daily, firmware weekly |

## Auto-Updates

| What | Frequency | Type |
|------|-----------|------|
| DNF security patches | Daily | Automatic apply |
| Flatpak apps | Daily | Automatic apply |
| Firmware (fwupd) | Weekly | Check + notify |

## GNOME Extensions

- **Dash to Dock** — Bottom dock with auto-hide and blur
- **Blur my Shell** — Blur effects on panel, dock, overview
- **Just Perfection** — Fine-tune GNOME Shell UI
- **Pop Shell** — Tiling window management
- **CoverflowAltTab** — 3D alt-tab switcher
- **gTile** — Grid-based window tiling
- **Caffeine** — Prevent screen sleep
- **Vitals** — System monitor (CPU, RAM, temp, network)
- **BingWallpaper** — Daily wallpaper + lock screen sync
- **Lockscreen Extension** — Lock screen customization
- **DDTerm** — Drop-down terminal
- **Search Light** — Spotlight search
- **GNOME UI Tune** — UI refinements
- **Desktop Icons (DING)** — Desktop icons
- **User Theme** — Shell themes
- **Launch New Instance** — New app windows

## Run Individual Modules

```bash
./setup.sh --module optimize
./setup.sh --module power
./setup.sh --module security
./setup.sh --module updates
./setup.sh extensions
./setup.sh themes
```

## Restore / Rollback

If you experience hardware incompatibility with the aggressive power saving or performance tweaks, you can revert them:

```bash
./setup.sh --restore
```

## Customization

| File | Purpose |
|------|---------|
| `configs/packages.list` | System packages (categorized, comment/uncomment) |
| `configs/flatpaks.list` | Flatpak apps (categorized) |
| `configs/extensions.list` | GNOME extension UUIDs |
| `configs/dconf-settings.ini` | GNOME desktop + extension settings |
| `configs/sysctl-performance.conf` | Kernel performance parameters |
| `configs/sysctl-power.conf` | Kernel power parameters |
| `configs/sysctl-security.conf` | Kernel security parameters |
| `configs/limits-performance.conf` | File descriptor / process limits |
| `configs/nvidia-power.conf` | NVIDIA power management |
| `configs/ssh-hardened.conf` | SSH server hardening |
| `configs/tuned/fedora-endurance/` | Custom tuned power profile |

### Export Your Own Settings

```bash
dconf dump /org/gnome/shell/extensions/ > my-extensions.ini
dconf dump /org/gnome/desktop/ > my-desktop.ini
```

## Structure

```
fedora-setup/
├── setup.sh                          # Main entry point
├── README.md
├── LICENSE
├── configs/
│   ├── packages.list                 # Categorized DNF packages
│   ├── flatpaks.list                 # Categorized Flatpak apps
│   ├── extensions.list               # GNOME extension UUIDs
│   ├── dconf-settings.ini            # GNOME dconf settings
│   ├── sysctl-power.conf             # Kernel power parameters
│   ├── sysctl-security.conf          # Kernel security parameters
│   ├── nvidia-power.conf             # NVIDIA GPU power management
│   ├── nvidia-pm-udev.rules          # NVIDIA udev power rules
│   ├── ssh-hardened.conf             # SSH hardening config
│   └── tuned/
│       └── fedora-endurance/
│           └── tuned.conf            # Custom tuned profile
└── modules/
    ├── detect.sh                     # System detection
    ├── repos.sh                      # Repository setup
    ├── packages.sh                   # Package installation
    ├── nvidia.sh                     # GPU driver setup
    ├── themes.sh                     # Theme configuration
    ├── extensions.sh                 # GNOME extension installer
    ├── gnome-settings.sh             # Desktop configuration
    ├── sudo.sh                       # Sudo configuration
    ├── optimize.sh                   # Performance optimization
    ├── power.sh                      # Power management
    ├── security.sh                   # Security hardening
    ├── updates.sh                    # System updates + auto-updates
    ├── backup.sh                     # Btrfs snapshots & backups
    ├── dev.sh                        # Developer environment (Podman, Toolbox, Zsh)
    ├── gaming.sh                     # Gaming tweaks (Steam, Gamemode)
    ├── debloat.sh                    # Removes telemetry and bloatware
    └── restore.sh                    # Rollback optimizations
```

## Requirements

- Fedora Linux (tested on 43, should work on 38+)
- GNOME desktop environment
- Internet connection

## License

MIT
