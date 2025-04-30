#!/bin/bash

# Set up dotfiles directory
DOTFILES_DIR="$(pwd)"

# Update and install base packages
echo "Updating system and installing base dependencies..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed zsh git zathura base-devel neovim tmux wl-clipboard \
    ghostty starship fastfetch noto-fonts noto-fonts-cjk noto-fonts-emoji \
    tree exa fzf --noconfirm

# Install AUR helper (paru)
echo "Installing AUR helper (paru)..."
git clone https://aur.archlinux.org/paru.git
cd paru || exit
makepkg -si --noconfirm
cd .. || exit

# Install additional AUR fonts and tools
echo "Installing additional AUR fonts and utilities..."
paru -S --needed ttf-freefont ttf-ms-fonts ttf-linux-libertine ttf-dejavu \
    ttf-inconsolata ttf-ubuntu-font-family auto-cpufreq capitaine-cursors --noconfirm

# Install Neovim plugin manager: packer.nvim
echo "Installing packer.nvim..."
git clone --depth 1 https://github.com/wbthomason/packer.nvim \
    ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# Install Tmux Plugin Manager (TPM)
echo "Installing Tmux Plugin Manager (TPM)..."
mkdir -p ~/.tmux/plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Install Zsh plugins
echo "Installing Zsh plugins..."
mkdir -p ~/.zsh
git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions

# Define target config directories
TARGET_NEOVIM_DIR="$HOME/.config/nvim"
TARGET_ZSHRC_DIR="$HOME"
TARGET_STARSHIP_DIR="$HOME/.config"
TARGET_TMUX_DIR="$HOME"
TARGET_GHOSTTY_DIR="$HOME/.config/ghostty"

# Ensure config directories exist
mkdir -p "$TARGET_NEOVIM_DIR"
mkdir -p "$TARGET_STARSHIP_DIR"
mkdir -p "$TARGET_TMUX_DIR"
mkdir -p "$TARGET_GHOSTTY_DIR"

# Copy dotfiles (replace existing ones)
echo "Copying dotfiles..."
cp -f "$DOTFILES_DIR/init.lua" "$TARGET_NEOVIM_DIR/"
cp -f "$DOTFILES_DIR/.zshrc" "$TARGET_ZSHRC_DIR/"
cp -f "$DOTFILES_DIR/starship.toml" "$TARGET_STARSHIP_DIR/"
cp -f "$DOTFILES_DIR/.tmux.conf" "$TARGET_TMUX_DIR/"
cp -f "$DOTFILES_DIR/ghostty/config" "$TARGET_GHOSTTY_DIR/"

echo "Dotfiles copied successfully!"

# Optional: Change shell to zsh
if [ "$SHELL" != "/bin/zsh" ]; then
    echo "Changing default shell to zsh..."
    chsh -s /bin/zsh
fi

echo "Installation complete! You may need to restart your shell or source .zshrc."
