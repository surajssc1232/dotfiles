#!/bin/bash

set -e  # Exit on error

# Set up dotfiles directory
DOTFILES_DIR="$(pwd)"
LOG_FILE="/tmp/dotfiles_install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------
# Logging Functions
# ---------------------------

log() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

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
        log "Installing missing packages: ${missing_pkgs[*]}"
        sudo pacman -S --needed --noconfirm "${missing_pkgs[@]}"
        success "Installed pacman packages: ${missing_pkgs[*]}"
    else
        log "All requested packages are already installed (pacman)."
    fi
}

install_aur_pkgs() {
    if ! command -v paru &>/dev/null; then
        error "paru is not installed yet."
        return 1
    fi

    local missing_aur_pkgs=()
    for pkg in "$@"; do
        if ! paru -Qs "^$pkg$" >/dev/null 2>&1; then
            missing_aur_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_aur_pkgs[@]} -gt 0 ]; then
        log "Installing missing AUR packages: ${missing_aur_pkgs[*]}"
        paru -S --needed --noconfirm "${missing_aur_pkgs[@]}"
        success "Installed AUR packages: ${missing_aur_pkgs[*]}"
    else
        log "All requested AUR packages are already installed."
    fi
}

safe_clone() {
    local repo_url="$1"
    local target_dir="$2"

    if [ -d "$target_dir" ]; then
        log "Skipping clone of $repo_url — already exists at $target_dir"
    else
        log "Cloning $repo_url to $target_dir"
        git clone "$repo_url" "$target_dir"
        success "Cloned $repo_url"
    fi
}

backup_existing() {
    local file_path="$1"
    if [ -e "$file_path" ]; then
        local backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$file_path" "$backup_path"
        warn "Backed up existing file: $file_path -> $backup_path"
    fi
}

# ---------------------------
# Installation Steps
# ---------------------------

main() {
    log "Starting dotfiles installation..."
    log "Installation log: $LOG_FILE"

    # Step 1: System Update
    log "Step 1: Updating system packages..."
    sudo pacman -Syu --noconfirm

    # Step 2: Install base packages (required for AUR helper)
    log "Step 2: Installing base packages..."
    BASE_PKGS=(
        base-devel git curl wget
    )
    install_pacman_pkgs "${BASE_PKGS[@]}"

    # Step 3: Install AUR helper (paru) if not present
    if ! command -v paru &>/dev/null; then
        log "Step 3: Installing AUR helper (paru)..."
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -si --noconfirm
        cd "$DOTFILES_DIR"
        rm -rf "$TEMP_DIR"
        success "Installed paru AUR helper"
    else
        log "Step 3: paru is already installed."
    fi

    # Step 4: Install core system packages
    log "Step 4: Installing core system packages..."
    CORE_PKGS=(
        # Shell and terminal
        zsh tmux
        # System utilities
        tree exa fzf polkit brightnessctl pavucontrol
        # Fonts
        noto-fonts noto-fonts-cjk noto-fonts-emoji
        # Audio/Video
        pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
        # Wayland essentials
        wayland xdg-desktop-portal xdg-desktop-portal-wlr
        # Screen capture
        grim slurp wf-recorder
        # Clipboard
        wl-clipboard
        # System monitoring
        power-profiles-daemon
        # Other utilities
        qbittorrent fastfetch
    )
    install_pacman_pkgs "${CORE_PKGS[@]}"

    # Step 5: Install applications
    log "Step 5: Installing applications..."
    APP_PKGS=(
        neovim zathura ghostty starship
    )
    install_pacman_pkgs "${APP_PKGS[@]}"

    # Step 6: Install AUR packages
    log "Step 6: Installing AUR packages..."
    AUR_PKGS=(
        # Fonts
        ttf-freefont ttf-ms-fonts ttf-linux-libertine ttf-dejavu
        ttf-inconsolata ttf-ubuntu-font-family
        # System utilities
        auto-cpufreq capitaine-cursors
        # Applications
        zen-browser-bin
        # Hyprland ecosystem
        hyprland swaync waybar
        # Rofi extensions
        rofi-wifi-menu-git rofi-bluetooth-git
    )
    install_aur_pkgs "${AUR_PKGS[@]}"

    # Step 7: Install plugin managers and dependencies
    log "Step 7: Installing plugin managers..."
    
    # Neovim plugin manager (Packer)
    safe_clone \
        https://github.com/wbthomason/packer.nvim \
        ~/.local/share/nvim/site/pack/packer/start/packer.nvim

    # Tmux Plugin Manager
    safe_clone \
        https://github.com/tmux-plugins/tpm \
        ~/.tmux/plugins/tpm

    # Zsh plugins
    ZSH_PLUGINS_DIR=~/.zsh
    mkdir -p "$ZSH_PLUGINS_DIR"
    safe_clone https://github.com/Aloxaf/fzf-tab "$ZSH_PLUGINS_DIR/fzf-tab"
    safe_clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions"
    safe_clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting"

    # Step 8: Create necessary directories
    log "Step 8: Creating configuration directories..."
    mkdir -p ~/.config/{nvim,ghostty,hypr,swaync,waybar,rofi,zathura,bat,tmux}
    mkdir -p ~/.local/share/applications
    mkdir -p ~/.local/bin

    # Step 9: Copy dotfiles with backups
    log "Step 9: Installing configuration files..."

    # Root dotfiles
    if [ -f "$DOTFILES_DIR/.zshrc" ]; then
        backup_existing ~/.zshrc
        cp "$DOTFILES_DIR/.zshrc" ~/
        success "Installed .zshrc"
    fi

    if [ -f "$DOTFILES_DIR/.tmux.conf" ]; then
        backup_existing ~/.tmux.conf
        cp "$DOTFILES_DIR/.tmux.conf" ~/
        success "Installed .tmux.conf"
    fi

    if [ -f "$DOTFILES_DIR/starship.toml" ]; then
        backup_existing ~/.config/starship.toml
        cp "$DOTFILES_DIR/starship.toml" ~/.config/
        success "Installed starship.toml"
    fi

    # Neovim configuration
    if [ -f "$DOTFILES_DIR/init.lua" ]; then
        backup_existing ~/.config/nvim/init.lua
        cp "$DOTFILES_DIR/init.lua" ~/.config/nvim/
        success "Installed Neovim configuration"
    elif [ -d "$DOTFILES_DIR/nvim" ]; then
        backup_existing ~/.config/nvim
        cp -r "$DOTFILES_DIR/nvim/"* ~/.config/nvim/
        success "Installed Neovim configuration"
    fi

    # Ghostty configuration
    if [ -d "$DOTFILES_DIR/ghostty" ]; then
        backup_existing ~/.config/ghostty
        mkdir -p ~/.config/ghostty
        if cp -r "$DOTFILES_DIR/ghostty/"* ~/.config/ghostty/ 2>/dev/null; then
            success "Installed Ghostty configuration"
        else
            warn "Failed to copy Ghostty configuration - directory may be empty"
        fi
    fi

    # Hyprland configuration
    if [ -d "$DOTFILES_DIR/hypr" ]; then
        backup_existing ~/.config/hypr
        mkdir -p ~/.config/hypr
        if cp -r "$DOTFILES_DIR/hypr/"* ~/.config/hypr/ 2>/dev/null; then
            success "Installed Hyprland configuration"
        else
            warn "Failed to copy Hyprland configuration - directory may be empty"
        fi
    fi

    # swaync configuration
    if [ -d "$DOTFILES_DIR/swaync" ]; then
        backup_existing ~/.config/swaync
        mkdir -p ~/.config/swaync
        if cp -r "$DOTFILES_DIR/swaync/"* ~/.config/swaync/ 2>/dev/null; then
            success "Installed swaync configuration"
        else
            warn "Failed to copy swaync configuration - directory may be empty"
        fi
    fi

    # waybar configuration
    if [ -d "$DOTFILES_DIR/waybar" ]; then
        backup_existing ~/.config/waybar
        mkdir -p ~/.config/waybar
        if cp -r "$DOTFILES_DIR/waybar/"* ~/.config/waybar/ 2>/dev/null; then
            # Make scripts executable
            find ~/.config/waybar -name "*.sh" -exec chmod +x {} \; 2>/dev/null
            find ~/.config/waybar -name "*.py" -exec chmod +x {} \; 2>/dev/null
            success "Installed waybar configuration"
        else
            warn "Failed to copy waybar configuration - directory may be empty"
        fi
    fi

    # rofi configuration
    if [ -d "$DOTFILES_DIR/rofi" ]; then
        backup_existing ~/.config/rofi
        mkdir -p ~/.config/rofi
        if cp -r "$DOTFILES_DIR/rofi/"* ~/.config/rofi/ 2>/dev/null; then
            # Make scripts executable
            find ~/.config/rofi -name "*.sh" -exec chmod +x {} \; 2>/dev/null
            success "Installed rofi configuration"
        else
            warn "Failed to copy rofi configuration - directory may be empty"
        fi
    fi

    # zathura configuration
    if [ -f "$DOTFILES_DIR/zathurarc" ]; then
        backup_existing ~/.config/zathura/zathurarc
        cp "$DOTFILES_DIR/zathurarc" ~/.config/zathura/
        success "Installed zathura configuration"
    elif [ -d "$DOTFILES_DIR/zathura" ]; then
        backup_existing ~/.config/zathura
        mkdir -p ~/.config/zathura
        if cp -r "$DOTFILES_DIR/zathura/"* ~/.config/zathura/ 2>/dev/null; then
            success "Installed zathura configuration"
        else
            warn "Failed to copy zathura configuration - directory may be empty"
        fi
    fi

    # bat configuration
    if [ -d "$DOTFILES_DIR/bat" ]; then
        backup_existing ~/.config/bat
        mkdir -p ~/.config/bat
        if cp -r "$DOTFILES_DIR/bat/"* ~/.config/bat/ 2>/dev/null; then
            success "Installed bat configuration"
        else
            warn "Failed to copy bat configuration - directory may be empty"
        fi
    fi

    # tmux configuration (additional)
    if [ -d "$DOTFILES_DIR/tmux" ]; then
        backup_existing ~/.config/tmux
        mkdir -p ~/.config/tmux
        if cp -r "$DOTFILES_DIR/tmux/"* ~/.config/tmux/ 2>/dev/null; then
            find ~/.config/tmux -name "*.sh" -exec chmod +x {} \; 2>/dev/null
            success "Installed additional tmux configuration"
        else
            warn "Failed to copy tmux configuration - directory may be empty"
        fi
    fi

    # Step 10: Make scripts executable
    log "Step 10: Making scripts executable..."
    find ~/.config/hypr/scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find ~/.config/rofi -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find ~/.config/waybar -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    # Step 11: Enable services
    log "Step 11: Enabling system services..."
    
    # Enable auto-cpufreq if installed
    if command -v auto-cpufreq &>/dev/null; then
        sudo systemctl enable --now auto-cpufreq
        success "Enabled auto-cpufreq service"
    fi

    # Step 12: Change default shell to zsh
    if [ "$SHELL" != "/bin/zsh" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
        log "Step 12: Changing default shell to zsh..."
        chsh -s /bin/zsh
        success "Changed default shell to zsh"
    else
        log "Step 12: Default shell is already zsh."
    fi

    # Step 13: Final setup
    log "Step 13: Final setup steps..."
    
    # Source zsh configuration to install plugins
    if [ -f ~/.zshrc ]; then
        warn "Please run 'source ~/.zshrc' after the script completes to initialize zsh plugins"
    fi

    # Install tmux plugins
    if [ -f ~/.tmux.conf ]; then
        warn "Please run 'prefix + I' in tmux to install plugins (prefix is usually Ctrl+b)"
    fi

    # Install neovim plugins
    if [ -f ~/.config/nvim/init.lua ]; then
        warn "Please run ':PackerSync' in Neovim to install plugins"
    fi

    success "✅ Dotfiles installation complete!"
    echo
    log "Next steps:"
    echo "1. Log out and log back in to use zsh as default shell"
    echo "2. Select 'Hyprland' from your display manager"
    echo "3. Run 'source ~/.zshrc' to initialize zsh plugins"
    echo "4. Open tmux and press prefix + I to install tmux plugins"
    echo "5. Open Neovim and run ':PackerSync' to install plugins"
    echo
    log "Installation log saved to: $LOG_FILE"
}

# ---------------------------
# Error Handling
# ---------------------------

cleanup() {
    if [ $? -ne 0 ]; then
        error "Installation failed. Check the log at $LOG_FILE"
        exit 1
    fi
}

trap cleanup EXIT

# ---------------------------
# Main Execution
# ---------------------------

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please do not run this script as root"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "install_dotfiles.sh" ]; then
    error "Please run this script from the dotfiles directory"
    exit 1
fi

# Start installation
main "$@"
