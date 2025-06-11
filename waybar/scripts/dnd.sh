#!/bin/bash

get_dnd_status() {
    if swaync-client -D | grep -q "true"; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

toggle_dnd() {
    swaync-client -d
    status=$(get_dnd_status)
    if [ "$status" = "enabled" ]; then
        notify-send -t 2000 "Do Not Disturb" "Enabled" -i dialog-information
    else
        notify-send -t 2000 "Do Not Disturb" "Disabled" -i dialog-information
    fi
}

waybar_output() {
    status=$(get_dnd_status)
    if [ "$status" = "enabled" ]; then
        echo '{"text": " 󰂛 ", "class": "dnd-on", "tooltip": "Do Not Disturb: ON\nClick to disable"}'
    else
        echo '{"text": " 󰂚 ", "class": "dnd-off", "tooltip": "Do Not Disturb: OFF\nClick to enable"}'
    fi
}

case "$1" in
    "toggle")
        toggle_dnd
        ;;
    "status")
        waybar_output
        ;;
    *)
        waybar_output
        ;;
esac
