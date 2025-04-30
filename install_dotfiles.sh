#!/bin/bash

# Set up dotfiles directory
DOTFILES_DIR="$(pwd)"

# ---------------------------
# Helper Functions
# ---------------------------

install_pacman_pkgs() {
    local missing_pkgs=()
    for pkg in "$@"; do
        if ! pacman -Qs "^$pkg$" >/dev/null 2>&1; then
            missing_pkgs+=("$pkg")
        fi
    done
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo "Installing missing packages: ${missing_pkgs[*]}"
        sudo pacman -S --needed --noconfirm "${missing_pkgs[@]}"
    else
        echo "All requested packages are already installed (pacman)."
    fi
}

install_aur_pkgs() {
    if ! command -v paru &>/dev/null; then
        echo "Error: paru is not installed yet." >&2
        return 1
    fi

    local missing_aur_pkgs=()
    for pkg in "$@"; do
        if ! paru -Qs "^$pkg$" >/dev/null 2>&1; then
            missing_aur_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_aur_pkgs[@]} -gt 0 ]; then
        echo "Installing missing AUR packages: ${missing_aur_pkgs[*]}"
        paru -S --needed --noconfirm "${missing_aur_pkgs[@]}"
    else
        echo "All requested AUR packages are already installed."
    fi
}

safe_clone() {
    local repo_url="$1"
    local target_dir="$2"

    if [ -d "$target_dir" ]; then
        echo "Skipping clone of $repo_url — already exists at $target_dir"
    else
        echo "Cloning $repo_url to $target_dir"
        git clone "$repo_url" "$target_dir"
    fi
}

# ---------------------------
# Main Installation Steps
# ---------------------------

echo "Updating system and checking base packages..."
sudo pacman -Syu --noconfirm

PACMAN_PKGS=(
    zsh git zathura base-devel neovim tmux wl-clipboard ghostty starship fastfetch
    noto-fonts noto-fonts-cjk noto-fonts-emoji tree exa fzf qbittorrent
)
install_pacman_pkgs "${PACMAN_PKGS[@]}"

if ! command -v paru &>/dev/null; then
    echo "Installing AUR helper (paru)..."
    git clone https://aur.archlinux.org/paru.git
    cd paru || exit
    makepkg -si --noconfirm
    cd .. || exit
else
    echo "paru is already installed."
fi

# Install AUR packages including zen-browser-bin
AUR_PKGS=(
    ttf-freefont ttf-ms-fonts ttf-linux-libertine ttf-dejavu
    ttf-inconsolata ttf-ubuntu-font-family auto-cpufreq capitaine-cursors
    zen-browser-bin
)
install_aur_pkgs "${AUR_PKGS[@]}"

# Install Neovim plugin manager
safe_clone \
    https://github.com/wbthomason/packer.nvim \
    ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# Install Tmux Plugin Manager
safe_clone \
    https://github.com/tmux-plugins/tpm \
    ~/.tmux/plugins/tpm

# Install Zsh plugins
ZSH_PLUGINS_DIR=~/.zsh
mkdir -p "$ZSH_PLUGINS_DIR"
safe_clone https://github.com/Aloxaf/fzf-tab "$ZSH_PLUGINS_DIR/fzf-tab"
safe_clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions"

# Copy dotfiles
TARGET_NEOVIM_DIR="$HOME/.config/nvim"
TARGET_ZSHRC_DIR="$HOME"
TARGET_STARSHIP_DIR="$HOME/.config"
TARGET_TMUX_DIR="$HOME"
TARGET_GHOSTTY_DIR="$HOME/.config/ghostty"

mkdir -p "$TARGET_NEOVIM_DIR" "$TARGET_STARSHIP_DIR" "$TARGET_TMUX_DIR" "$TARGET_GHOSTTY_DIR"

echo "Copying dotfiles (overwriting existing ones)..."
cp -f "$DOTFILES_DIR/init.lua" "$TARGET_NEOVIM_DIR/"
cp -f "$DOTFILES_DIR/.zshrc" "$TARGET_ZSHRC_DIR/"
cp -f "$DOTFILES_DIR/starship.toml" "$TARGET_STARSHIP_DIR/"
cp -f "$DOTFILES_DIR/.tmux.conf" "$TARGET_TMUX_DIR/"
cp -f "$DOTFILES_DIR/ghostty/config" "$TARGET_GHOSTTY_DIR/"

# Change shell to zsh if needed
if [ "$SHELL" != "/bin/zsh" ]; then
    echo "Changing default shell to zsh..."
    chsh -s /bin/zsh
else
    echo "Default shell is already zsh."
fi

echo "✅ Installation complete! You may need to restart your shell or run 'source ~/.zshrc'."
