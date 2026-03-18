#!/usr/bin/env bash
# Developer Environment setup — Podman, Toolbox, NVM, Zsh, Starship
# Philosophy: Isolate dev dependencies from the host OS to maintain stability

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_dev_env() {
    echo ""
    echo -e "${BOLD}━━━ Setting up Developer Environment ━━━${NC}"

    install_podman
    install_toolbox
    install_nvm
    setup_terminal

    echo ""
    echo "[OK] Developer environment configured"
}

install_podman() {
    echo ""
    echo "[+] Configuring Podman (Daemonless Container Engine)..."

    # Install Podman and essential plugins
    sudo dnf install -y podman podman-compose podman-docker toolbox 2>&1 | tail -2

    # Enable lingering so rootless containers can run in the background
    loginctl enable-linger "$USER"

    # Set up user-level systemd directory for Podman containers
    mkdir -p "$HOME/.config/systemd/user"

    echo "  [OK] Podman installed and configured for rootless operation"
    echo "  [OK] 'podman-docker' installed (you can still use the 'docker' command)"
}

install_toolbox() {
    echo ""
    echo "[+] Configuring Toolbox (Isolated Dev Environments)..."

    # Toolbox allows developers to install libraries and build tools
    # inside a container without polluting the host OS.
    if ! command -v toolbox &>/dev/null; then
        sudo dnf install -y toolbox 2>&1 | tail -2
    fi

    # Automatically create the default toolbox if it doesn't exist
    if ! toolbox list | grep -q "fedora-toolbox"; then
        echo "  [+] Creating default Fedora toolbox container..."
        # Run in background to not block the script, as it downloads an image
        toolbox create -y > /dev/null 2>&1 &
        echo "  [OK] Default toolbox is being created in the background."
    else
        echo "  [OK] Default toolbox already exists."
    fi

    echo "  [NOTE] Run 'toolbox enter' later to access your isolated dev environment."
}
install_nvm() {
    echo ""
    echo "[+] Installing Node Version Manager (NVM)..."

    if [[ ! -d "$HOME/.nvm" ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash 2>/dev/null
        echo "  [OK] NVM installed"
    else
        echo "  [OK] NVM already installed"
    fi
}

setup_terminal() {
    echo ""
    echo "[+] Setting up modern terminal (Zsh + Starship)..."

    sudo dnf install -y zsh util-linux-user 2>/dev/null | tail -1

    if ! command -v starship &>/dev/null; then
        curl -sS https://starship.rs/install.sh | sh -s -- -y > /dev/null 2>&1
    fi

    # Configure Zsh
    local zshrc="$HOME/.zshrc"
    if [[ ! -f "$zshrc" ]] || ! grep -q "starship init" "$zshrc"; then
        cat << 'EOF' >> "$zshrc"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Starship Prompt
eval "$(starship init zsh)"

# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias update='sudo dnf upgrade --refresh'
EOF
        echo "  [OK] Zsh and Starship configured"
    fi

    # Change default shell to Zsh
    local current_shell
    current_shell=$(basename "$SHELL")
    if [[ "$current_shell" != "zsh" ]]; then
        chsh -s "$(which zsh)"
        echo "  [OK] Default shell changed to Zsh (takes effect after logout)"
    fi
}
