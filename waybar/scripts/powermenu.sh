#!/bin/bash

# Define options with Unicode icons and text labels (Nerd Fonts)
options=" Shutdown\n Reboot\n Logout\n Lock"

# Pipe options to fuzzel, get selected option
selected=$(echo -e "$options" | fuzzel --dmenu )

# Execute the selected action based on the icon + text
case "$selected" in
    " Shutdown") systemctl poweroff ;;  # Shutdown
    " Reboot") systemctl reboot ;;      # Reboot
    " Logout") niri msg action quit;; # Logout for Hyprland
    " Lock") niri msg action quit --skip-confirmation;;               # Lock for Hyprland
esac
