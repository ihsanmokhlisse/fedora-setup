#!/usr/bin/env bash
# Repository setup — RPM Fusion, Flathub, Cisco OpenH264, Cursor, Chrome, Terra, Copr

setup_repos() {
    echo ""
    echo "━━━ Setting up repositories ━━━"

    if [[ "$PKG_MANAGER" != "dnf" ]]; then
        echo "[SKIP] Not a DNF-based system, skipping repo setup."
        return 0
    fi

    local fedora_ver
    fedora_ver=$(rpm -E %fedora)

    # --- RPM Fusion (free) — ffmpeg, VLC, codecs ---
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        echo "[+] Installing RPM Fusion (free) — multimedia codecs, VLC..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
            || echo "[WARN] Failed to install RPM Fusion free"
    else
        echo "[OK] RPM Fusion (free) already installed"
    fi

    # --- RPM Fusion (nonfree) — NVIDIA drivers, Steam ---
    if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
        echo "[+] Installing RPM Fusion (nonfree) — NVIDIA drivers, Steam..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm" \
            || echo "[WARN] Failed to install RPM Fusion nonfree"
    else
        echo "[OK] RPM Fusion (nonfree) already installed"
    fi

    # --- Cisco OpenH264 (H.264 codec for Firefox/WebRTC) ---
    if ! dnf repolist --enabled 2>/dev/null | grep -q "fedora-cisco-openh264"; then
        echo "[+] Enabling Cisco OpenH264 repository..."
        sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1 2>/dev/null || \
        sudo dnf config-manager --set-enabled fedora-cisco-openh264 2>/dev/null || true
    else
        echo "[OK] Cisco OpenH264 repo already enabled"
    fi

    # --- Fedora multimedia codec swap (replace limited Fedora codecs with full RPM Fusion ones) ---
    echo "[+] Swapping Fedora limited codecs for full RPM Fusion codecs..."
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing 2>/dev/null || true
    sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing 2>/dev/null || true
    sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld --allowerasing 2>/dev/null || true

    # --- Terra Repository ---
    if ! rpm -q terra-release &>/dev/null; then
        echo "[+] Installing Terra repository..."
        sudo dnf install -y --repofrompath \
            "terra,https://repos.fyralabs.com/terra${fedora_ver}" \
            terra-release 2>/dev/null \
            || echo "[WARN] Failed to install Terra repo"
    else
        echo "[OK] Terra repository already installed"
    fi

    # --- Google Chrome ---
    if [[ ! -f /etc/yum.repos.d/google-chrome.repo ]]; then
        echo "[+] Adding Google Chrome repository..."
        sudo tee /etc/yum.repos.d/google-chrome.repo > /dev/null <<'REPO'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
enabled=1
REPO
    else
        echo "[OK] Google Chrome repo already configured"
    fi

    # --- Cursor IDE ---
    if [[ ! -f /etc/yum.repos.d/cursor.repo ]]; then
        echo "[+] Adding Cursor IDE repository..."
        sudo tee /etc/yum.repos.d/cursor.repo > /dev/null <<'REPO'
[cursor]
name=Cursor
baseurl=https://downloads.cursor.com/yumrepo
enabled=1
gpgcheck=1
gpgkey=https://downloads.cursor.com/keys/anysphere.asc
repo_gpgcheck=1
REPO
    else
        echo "[OK] Cursor IDE repo already configured"
    fi

    # --- Copr: PyCharm ---
    if ! dnf copr list 2>/dev/null | grep -q "phracek/PyCharm"; then
        echo "[+] Enabling Copr: PyCharm..."
        sudo dnf copr enable -y phracek/PyCharm 2>/dev/null \
            || echo "[WARN] Failed to enable PyCharm Copr"
    else
        echo "[OK] Copr: PyCharm already enabled"
    fi

    # --- Copr: python-validity (fingerprint reader) ---
    if ! dnf copr list 2>/dev/null | grep -q "tigro/python-validity"; then
        echo "[+] Enabling Copr: python-validity..."
        sudo dnf copr enable -y tigro/python-validity 2>/dev/null \
            || echo "[WARN] Failed to enable python-validity Copr"
    else
        echo "[OK] Copr: python-validity already enabled"
    fi

    # --- Flathub ---
    if ! flatpak remote-list 2>/dev/null | grep -q "flathub"; then
        echo "[+] Adding Flathub repository..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    else
        echo "[OK] Flathub already configured"
    fi

    echo "[+] Refreshing package metadata..."
    sudo dnf makecache -q 2>/dev/null || true

    echo "[OK] All repositories configured"
}
