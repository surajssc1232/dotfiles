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
    xdg-desktop-portal xdg-desktop-portal-wlr polkit brightnessctl pavucontrol
    grim slurp wf-recorder wayland wlroots pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber power-profiles-daemon
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

AUR_PKGS=(
    ttf-freefont ttf-ms-fonts ttf-linux-libertine ttf-dejavu
    ttf-inconsolata ttf-ubuntu-font-family auto-cpufreq capitaine-cursors
    zen-browser-bin hyprland swaync waybar rofi-wifi-menu-git rofi-bluetooth-git
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

# ---------------------------
# Copy Dotfiles
# ---------------------------

echo "Copying dotfiles (overwriting existing ones)..."

# Main dotfiles
mkdir -p ~/.config/nvim ~/.config ~/.config/ghostty
cp -f "$DOTFILES_DIR/init.lua" ~/.config/nvim/
cp -f "$DOTFILES_DIR/.zshrc" ~/
cp -f "$DOTFILES_DIR/starship.toml" ~/.config/
cp -f "$DOTFILES_DIR/.tmux.conf" ~/
cp -f "$DOTFILES_DIR/ghostty/config" ~/.config/ghostty/

# Hyprland configs
mkdir -p ~/.config/hypr
cp -r "$DOTFILES_DIR/hypr/"* ~/.config/hypr/

# swaync configs
mkdir -p ~/.config/swaync
cp -r "$DOTFILES_DIR/swaync/"* ~/.config/swaync/

# waybar configs
mkdir -p ~/.config/waybar
cp -r "$DOTFILES_DIR/waybar/"* ~/.config/waybar/

# rofi configs
mkdir -p ~/.config/rofi
cp -r "$DOTFILES_DIR/rofi/"* ~/.config/rofi/

# Change shell to zsh
if [ "$SHELL" != "/bin/zsh" ]; then
    echo "Changing default shell to zsh..."
    chsh -s /bin/zsh
else
    echo "Default shell is already zsh."
fi

echo "✅ Hyprland setup complete! You can now log in using the Hyprland session."

