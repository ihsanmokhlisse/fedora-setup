<div align="center">
  
# 🌊 FedoraFlow
**The Ultimate One-Shot Post-Install Toolkit for Fedora Linux**

[![Fedora](https://img.shields.io/badge/Fedora-39%20%7C%2040%20%7C%2041%20%7C%2042%20%7C%2043-294172?style=for-the-badge&logo=fedora&logoColor=white)](#)
[![Bash](https://img.shields.io/badge/Script-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=for-the-badge)](#)

*Transform a fresh Fedora install into the most optimized, powerful, and secure GNOME desktop possible—in a single command.*

[Features](#-features) • [Installation](#-quick-start) • [Profiles](#-setup-profiles) • [Philosophy](#-the-fedoraflow-philosophy) • [Contributing](#-contributing)

</div>

---

## 💡 What is FedoraFlow?

Fedora is an incredible operating system, but out of the box, it requires hours of tweaking to reach its full potential. You have to install proprietary codecs, fix font rendering, optimize battery life, configure ZRAM, and set up your development or gaming environments.

**FedoraFlow automates all of this.** It is an intelligent, hardware-aware script that detects your system (Laptop/Desktop, NVIDIA/AMD/Intel, Wayland/X11) and applies the absolute best configurations for performance, efficiency, and security.

## 🚀 Quick Start

Run the following command in your terminal to clone and launch the interactive setup:

```bash
git clone https://github.com/ihsanmokhlisse/fedora-setup.git
cd fedora-setup
chmod +x setup.sh
./setup.sh
```

**Zero-Touch Deployment:** Want to bypass the menu? Pass a profile flag directly:
```bash
./setup.sh --profile ultimate
```

---

## 🎭 Setup Profiles

FedoraFlow uses a **Profile System**. Every profile includes the core performance, power, and security optimizations, but adds specific tools tailored to your workflow.

| Profile | Command | Best For | What's Included |
|---------|---------|----------|-----------------|
| **Standard** | `--profile standard` | General Users | The ultimate baseline. ZRAM tuning, Btrfs snapshots, Tuned power profiles, Firewalld hardening, MS Fonts, UI tweaks, and hardware video acceleration. |
| **Developer** | `--profile dev` | Software Engineers | *Standard* + **Podman** (rootless containers), **Toolbox** (isolated dev environments), **NVM**, **Zsh**, **Starship** prompt, **Flatpak IDE integration** (flatpak-spawn), and **GNU Stow** (dotfiles management). |
| **Gamer** | `--profile gaming` | Linux Gamers | *Standard* + **Steam**, **Lutris**, **Gamemode**, **MangoHud**, 32-bit Vulkan libs, and the crucial `vm.max_map_count` kernel tweak. |
| **Ultimate** | `--profile ultimate` | Power Users | *Standard* + *Developer* + *Gamer* + **Debloat** (safely removes GNOME bloatware and completely disables Fedora/GNOME telemetry). |

---

## ✨ Features Deep Dive

<details>
<summary><b>🔋 Power Management (The "MacBook-ification" of Fedora)</b></summary>

* **auto-cpufreq:** Dynamically adjusts the CPU governor and turbo boost in real-time based on load and power state. Performance on AC, Powersave on battery—automatically.
* **Custom Tuned Profile:** Installs a custom `fedora-endurance` profile balancing performance and battery.
* **NVIDIA D3cold Suspend:** Forces NVIDIA GPUs to completely power down when not in use (Saves 5-15W of power).
* **Battery Longevity:** Automatically detects laptop batteries and sets charge thresholds to 75-80% to prevent battery degradation.
* **Kernel Tweaks:** Disables NMI watchdog and forces PCIe ASPM to `powersupersave`.
</details>

<details>
<summary><b>⚡ Performance & Optimization</b></summary>

* **Advanced ZRAM:** Replaces default `lzo-rle` with `zstd` compression, expands ZRAM to 100% of physical RAM, and sets `vm.swappiness=100` for maximum memory efficiency.
* **Network Speed:** Enables TCP BBR congestion control, TCP Fast Open, and aggressive DNS caching while disabling LLMNR timeouts.
* **I/O & Disk:** Sets NVMe schedulers to `none`, increases read-ahead to 2048KB, and adds `noatime` to Btrfs mounts.
* **Browser Hardware Acceleration:** Injects flags into Chrome/Brave/Firefox to force Wayland and VA-API GPU video decoding (drastically lowers CPU usage on YouTube/Netflix).
* **Dual-Boot Fix:** Forces hardware clock to Local Time to prevent Windows/Linux time desync.
* **Bluetooth Audio:** Forces PipeWire to prioritize high-quality codecs (LDAC > aptX HD > aptX > AAC > SBC) and enables mSBC wideband speech for crystal-clear mic quality on calls.
</details>

<details>
<summary><b>🛡️ Security & Reliability</b></summary>

* **Bulletproof Btrfs Snapshots:** Installs `timeshift` and `grub-btrfs`. Automatically takes a zero-byte filesystem snapshot *before* every DNF update. If an update breaks your system, just select the snapshot from the GRUB boot menu to instantly restore it.
* **Firewall Hardening:** Switches from the permissive `FedoraWorkstation` zone to a tight `home` zone, auto-detecting and opening only necessary ports (like Synergy or SSH).
* **SSH & Kernel:** Disables root SSH login, enforces key-only auth, installs `fail2ban`, and applies kernel hardening parameters (kptr_restrict, ASLR).
* **USB Protection:** Blocks automatic mounting of new USB storage devices while the screen is locked.
</details>

<details>
<summary><b>🎨 Desktop & UI Fixes</b></summary>

* **Font Rendering:** Enables `rgba` subpixel antialiasing and installs Microsoft Core Fonts (Arial, Times New Roman) so web and office documents render perfectly.
* **GNOME Annoyances Fixed:** Automatically enables tap-to-click, fractional scaling (Wayland), and fixes Nautilus to sort folders first and use list view.
* **Flatpak Integration:** Exposes `~/.themes`, `~/.icons`, and `~/.fonts` to Flatpaks globally so containerized apps don't look ugly and out of place.
</details>

<details>
<summary><b>👨‍💻 Developer Experience (Dev Profile)</b></summary>

* **Podman + Toolbox:** Rootless, daemonless containers and isolated dev environments. Install messy build tools inside Toolbox without affecting the host OS.
* **Flatpak IDE Integration:** Installs `flatpak-spawn` and creates host-wrapper scripts so Flatpak-sandboxed IDEs (VS Code, Cursor) can access host tools like `git`, `node`, `python3`, `podman`, etc.
* **GNU Stow:** Automatically detects and symlinks a `~/.dotfiles` repository. Manage your `.zshrc`, `.gitconfig`, and `starship.toml` across machines effortlessly.
* **NVM:** Node Version Manager for clean, per-project Node.js versions without polluting the system.
* **Zsh + Starship:** A beautiful, fast, git-aware terminal prompt out of the box.
</details>

---

## 🧠 The FedoraFlow Philosophy

1. **Sane Defaults over "Rice":** We don't just install flashy themes. We fix fundamental OS bottlenecks and hardware quirks.
2. **Idempotency:** You can run this script 100 times. It checks if a setting is applied before touching it. It will never break an already-configured system.
3. **Isolation (Dev Profile):** We use `Podman` and `Toolbox` instead of installing messy development libraries directly onto the host OS. Keep your host system pristine and unbreakable.
4. **Safety Net:** Don't like the optimizations? Run `./setup.sh --restore` to cleanly revert kernel parameters, udev rules, and power profiles back to Fedora defaults.

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

Please read our [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## 💖 Support & Sponsor

If FedoraFlow saved you hours of setup time, made your laptop battery last longer, or saved your system from a broken update via Btrfs snapshots, consider supporting the project!

* ⭐ **Star this repository** (It really helps!)
* 📢 **Share it** on Reddit (`r/Fedora`, `r/Linux`) or Twitter.
* ☕ **[Sponsor the Developer](https://github.com/sponsors/ihsanmokhlisse)**

---

<div align="center">
  <i>Built with ❤️ for the Fedora Community.</i>
</div>
