#!/usr/bin/env bash

font=$(fc-list --format="%{family}\n" | tr ',' '\n' | sed 's/^ *//' | sort -u | fuzzel --dmenu --prompt="Font: ")

[[ -z "$font" ]] && exit 0

# Ghostty
sed -i "s/^font-family = .*/font-family = $font/" ~/.config/ghostty/config

# Alacritty
sed -i "s/^normal\.family=.*/normal.family=\"$font\"/" ~/.config/alacritty/alacritty.toml

# Fuzzel
sed -i "s/^font=.*/font=$font:size=13/" ~/.config/fuzzel/fuzzel.ini

# Foot
sed -i "s/^font=.*/font=$font:size=12/" ~/.config/foot/foot.ini

notify-send "Font changed" "$font" 2>/dev/null || true
