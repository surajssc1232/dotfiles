#!/bin/bash

# Set up dotfiles directory
DOTFILES_DIR="$(pwd)"

# ---------------------------
# Helper Functions
# ---------------------------

# Check and install packages via pacman (if not already installed)
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

# Check and install AUR packages via paru
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

# Clone repo if target dir doesn't exist
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

# Step 1: Update system and install base dependencies
echo "Updating system and checking base packages..."
sudo pacman -Syu --noconfirm

# List of main packages grouped for clarity
PACMAN_PKGS=(
    zsh git zathura base-devel neovim tmux wl-clipboard ghostty starship fastfetch
    noto-fonts noto-fonts-cjk noto-fonts-emoji tree exa fzf
)

install_pacman_pkgs "${PACMAN_PKGS[@]}"

# Step 2: Install paru (AUR helper), if not already present
if ! command -v paru &>/dev/null; then
    echo "paru not found. Installing paru..."
    git clone https://aur.archlinux.org/paru.git
    cd paru || exit
    makepkg -si --noconfirm
    cd .. || exit
else
    echo "paru is already installed."
fi

# Step 3: Install AUR packages
AUR_PKGS=(
    ttf-freefont ttf-ms-fonts ttf-linux-libertine ttf-dejavu
    ttf-inconsolata ttf-ubuntu-font-family auto-cpufreq capitaine-cursors
)

install_aur_pkgs "${AUR_PKGS[@]}"

# Step 4: Install Neovim plugin manager (packer.nvim), if not already installed
safe_clone \
    https://github.com/wbthomason/packer.nvim \
    ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# Step 5: Install Tmux Plugin Manager (TPM), if not already installed
safe_clone \
    https://github.com/tmux-plugins/tpm \
    ~/.tmux/plugins/tpm

# Step 6: Install Zsh plugins, if not already cloned
ZSH_PLUGINS_DIR=~/.zsh
mkdir -p "$ZSH_PLUGINS_DIR"

safe_clone \
    https://github.com/Aloxaf/fzf-tab \
    "$ZSH_PLUGINS_DIR/fzf-tab"

safe_clone \
    https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_PLUGINS_DIR/zsh-autosuggestions"

# Step 7: Copy dotfiles
TARGET_NEOVIM_DIR="$HOME/.config/nvim"
TARGET_ZSHRC_DIR="$HOME"
TARGET_STARSHIP_DIR="$HOME/.config"
TARGET_TMUX_DIR="$HOME"
TARGET_GHOSTTY_DIR="$HOME/.config/ghostty"

mkdir -p "$TARGET_NEOVIM_DIR"
mkdir -p "$TARGET_STARSHIP_DIR"
mkdir -p "$TARGET_TMUX_DIR"
mkdir -p "$TARGET_GHOSTTY_DIR"

echo "Copying dotfiles (overwriting existing ones)..."
cp -f "$DOTFILES_DIR/init.lua" "$TARGET_NEOVIM_DIR/"
cp -f "$DOTFILES_DIR/.zshrc" "$TARGET_ZSHRC_DIR/"
cp -f "$DOTFILES_DIR/starship.toml" "$TARGET_STARSHIP_DIR/"
cp -f "$DOTFILES_DIR/.tmux.conf" "$TARGET_TMUX_DIR/"
cp -f "$DOTFILES_DIR/ghostty/config" "$TARGET_GHOSTTY_DIR/"

echo "Dotfiles copied successfully!"

# Step 8: Optionally change shell to zsh
if [ "$SHELL" != "/bin/zsh" ]; then
    echo "Changing default shell to zsh..."
    chsh -s /bin/zsh
else
    echo "Default shell is already zsh."
fi

echo "✅ Installation complete! You may need to restart your shell or source .zshrc."
