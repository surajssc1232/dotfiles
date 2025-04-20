#!/bin/bash


# installing packer
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# installing tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Define the dotfiles directory (it will be the current directory after cloning)
DOTFILES_DIR="$(pwd)"

# Define the target directories where the dotfiles should go
TARGET_ZSHRC_DIR="$HOME"
TARGET_LUA_DIR="$HOME/.config/nvim"  # Change this if you store init.lua somewhere else
TARGET_STARSHIP_DIR="$HOME/.config"  # Change this if necessary
TARGET_TMUX_DIR="$HOME"
TARGET_GHOSTTY_DIR="$HOME/.config/ghostty"

# Ensure the target directories exist
mkdir -p "$TARGET_LUA_DIR"
mkdir -p "$TARGET_STARSHIP_DIR"
mkdir -p "$TARGET_GHOSTTY_DIR"
# Copy the files, replacing any existing files
cp -f "$DOTFILES_DIR/init.lua" "$TARGET_LUA_DIR/init.lua"
cp -f "$DOTFILES_DIR/.zshrc" "$TARGET_ZSHRC_DIR/.zshrc"
cp -f "$DOTFILES_DIR/starship.toml" "$TARGET_STARSHIP_DIR/starship.toml"
cp -f "$DOTFILES_DIR/.tmux.conf" "$TARGET_TMUX_DIR/.tmux.conf"
cp -f "$DOTFILES_DIR/ghostty/config" "$TARGET_GHOSTTY_DIR/config"

echo "Dotfiles have been placed successfully!"

