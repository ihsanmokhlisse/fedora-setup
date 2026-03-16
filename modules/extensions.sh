#!/usr/bin/env bash
# GNOME extensions installer — installs from extensions.gnome.org using UUIDs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

get_extension_info() {
    local uuid="$1"
    local gnome_ver="$2"
    curl -sf "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${gnome_ver}" 2>/dev/null
}

get_download_url() {
    local uuid="$1"
    local gnome_ver="$2"
    local info
    info=$(get_extension_info "$uuid" "$gnome_ver")
    [[ -z "$info" ]] && return 1

    local pk version_tag
    pk=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); v=d.get('shell_version_map',{}); sk=sorted(v.keys(),key=lambda x: int(x) if x.isdigit() else 0, reverse=True); print(v[sk[0]]['pk'] if sk else '')" 2>/dev/null)

    [[ -z "$pk" ]] && return 1
    echo "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${pk}"
}

install_extension() {
    local uuid="$1"
    local gnome_ver="$2"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/${uuid}"

    if [[ -d "$ext_dir" ]]; then
        echo "  [OK] ${uuid} (already installed)"
        return 0
    fi

    local download_url
    download_url=$(get_download_url "$uuid" "$gnome_ver")

    if [[ -z "$download_url" ]]; then
        echo "  [!!] ${uuid} — not found for GNOME ${gnome_ver}, trying D-Bus install..."

        if command -v gnome-extensions &>/dev/null && [[ -n "$DISPLAY$WAYLAND_DISPLAY" ]]; then
            busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions \
                org.gnome.Shell.Extensions InstallRemoteExtension s "$uuid" 2>/dev/null && \
                echo "  [OK] ${uuid} (installed via D-Bus)" && return 0
        fi

        echo "  [FAIL] ${uuid} — could not install (no compatible version found)"
        return 1
    fi

    local tmp_zip
    tmp_zip=$(mktemp /tmp/ext-XXXXXX.zip)

    if ! curl -sfL "$download_url" -o "$tmp_zip" || [[ ! -s "$tmp_zip" ]]; then
        echo "  [!!] ${uuid} — download failed, trying D-Bus install..."
        rm -f "$tmp_zip"

        if command -v gnome-extensions &>/dev/null && [[ -n "$DISPLAY$WAYLAND_DISPLAY" ]]; then
            busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions \
                org.gnome.Shell.Extensions InstallRemoteExtension s "$uuid" 2>/dev/null && \
                echo "  [OK] ${uuid} (installed via D-Bus)" && return 0
        fi

        echo "  [FAIL] ${uuid} — could not install"
        return 1
    fi

    mkdir -p "$ext_dir"
    unzip -qo "$tmp_zip" -d "$ext_dir" 2>/dev/null

    if [[ -f "${ext_dir}/metadata.json" ]]; then
        if [[ -d "${ext_dir}/schemas" ]]; then
            glib-compile-schemas "${ext_dir}/schemas/" 2>/dev/null || true
        fi
        echo "  [OK] ${uuid}"
    else
        echo "  [FAIL] ${uuid} — invalid extension archive"
        rm -rf "$ext_dir"
    fi

    rm -f "$tmp_zip"
}

install_extensions() {
    echo ""
    echo "━━━ Installing GNOME Shell Extensions ━━━"

    if ! require_gnome; then
        return 0
    fi

    local ext_file="${SCRIPT_DIR}/configs/extensions.list"

    if [[ ! -f "$ext_file" ]]; then
        echo "[ERROR] Extension list not found: $ext_file"
        return 1
    fi

    if [[ -z "$GNOME_VER" ]]; then
        echo "[ERROR] Could not detect GNOME Shell version"
        return 1
    fi

    local gnome_major="${GNOME_MAJOR}"
    echo "[+] Installing extensions for GNOME Shell ${GNOME_VER} (major: ${gnome_major})..."
    echo ""

    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -z "$line" ]] && continue
        install_extension "$line" "$gnome_major"
    done < "$ext_file"

    echo ""
    echo "[+] Enabling all extensions..."

    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -z "$line" ]] && continue
        gnome-extensions enable "$line" 2>/dev/null || true
    done < "$ext_file"

    echo "[OK] Extension installation complete"
    echo "[NOTE] You may need to log out and back in for extensions to fully activate."
}
