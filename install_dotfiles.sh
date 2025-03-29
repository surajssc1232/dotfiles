#!/bin/bash

# Define the dotfiles directory (it will be the current directory after cloning)
DOTFILES_DIR="$(pwd)"

# Define the target directories where the dotfiles should go
TARGET_ZSHRC_DIR="$HOME"
TARGET_LUA_DIR="$HOME/.config/nvim"  # Change this if you store init.lua somewhere else
TARGET_STARSHIP_DIR="$HOME/.config/starship"  # Change this if necessary

# Ensure the target directories exist
mkdir -p "$TARGET_LUA_DIR"
mkdir -p "$TARGET_STARSHIP_DIR"

# Copy the files, replacing any existing files
cp -f "$DOTFILES_DIR/init.lua" "$TARGET_LUA_DIR/init.lua"
cp -f "$DOTFILES_DIR/.zshrc" "$TARGET_ZSHRC_DIR/.zshrc"
cp -f "$DOTFILES_DIR/starship.toml" "$TARGET_STARSHIP_DIR/starship.toml"

echo "Dotfiles have been placed successfully!"

