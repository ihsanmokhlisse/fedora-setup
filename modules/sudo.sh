#!/usr/bin/env bash
# Passwordless sudo configuration

configure_sudo() {
    echo ""
    echo "━━━ Configuring Sudo ━━━"

    local current_user
    current_user=$(whoami)

    if [[ "$current_user" == "root" ]]; then
        echo "[SKIP] Running as root, sudo config not needed."
        return 0
    fi

    local sudoers_file="/etc/sudoers.d/${current_user}"

    if [[ -f "$sudoers_file" ]]; then
        echo "[OK] Passwordless sudo already configured for ${current_user}"
        return 0
    fi

    echo "[+] Setting up passwordless sudo for ${current_user}..."

    echo "${current_user} ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_file" > /dev/null
    sudo chmod 440 "$sudoers_file"

    if sudo -n true 2>/dev/null; then
        echo "[OK] Passwordless sudo configured for ${current_user}"
    else
        echo "[FAIL] Sudo configuration failed"
        return 1
    fi
}
