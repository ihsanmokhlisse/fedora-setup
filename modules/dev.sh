#!/usr/bin/env bash
# Developer Environment setup — Docker, NVM, Zsh, Starship

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_dev_env() {
    echo ""
    echo -e "${BOLD}━━━ Setting up Developer Environment ━━━${NC}"

    install_docker
    install_nvm
    setup_terminal

    echo ""
    echo "[OK] Developer environment configured"
}

install_docker() {
    echo ""
    echo "[+] Configuring Docker engine..."

    if ! command -v docker &>/dev/null; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1 | tail -2
    fi

    sudo systemctl enable --now docker 2>/dev/null
    
    # Add user to docker group to avoid needing sudo
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        sudo usermod -aG docker "$USER"
        echo "  [OK] Added $USER to docker group (takes effect after logout/reboot)"
    else
        echo "  [OK] User already in docker group"
    fi
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
