#!/bin/bash

# Directory to save screenshots
screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"

# Timestamped filename
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
filename="$screenshot_dir/screenshot_$timestamp.png"

# Prompt user for screenshot mode
choice=$(echo -e "Whole Screen\nWindow\nRegion" | fuzzel --dmenu --prompt="Screenshot: ")

# Function to copy to clipboard and notify
finalize_screenshot() {
    wl-copy < "$filename"
    notify-send "Screenshot Taken" "Saved to $filename and copied to clipboard"
}

case "$choice" in
    "Whole Screen")
        grim "$filename" && finalize_screenshot
        ;;

    "Region")
        region=$(slurp)
        if [ -n "$region" ]; then
            grim -g "$region" "$filename" && finalize_screenshot
        else
            notify-send "Screenshot Cancelled" "No region selected"
        fi
        ;;

    "Window")
        # Get windows with swaymsg
        window_json=$(swaymsg -t get_tree)

        # Build menu with list of window names and IDs
        window_list=$(echo "$window_json" | jq -r '.. | select(.type? == "con" and .nodes == []) | "\(.id) \(.name)"' | grep -v '^0 ')

        selected_entry=$(echo "$window_list" | fuzzel --dmenu --prompt="Select Window:")

        selected_id=$(echo "$selected_entry" | awk '{print $1}')

        if [ -n "$selected_id" ]; then
            # Get geometry of selected window
            window_info=$(echo "$window_json" | jq --arg id "$selected_id" 'recurse(.nodes[]) | select(.id|tostring == $id)')
            x=$(echo "$window_info" | jq '.rect.x')
            y=$(echo "$window_info" | jq '.rect.y')
            width=$(echo "$window_info" | jq '.rect.width')
            height=$(echo "$window_info" | jq '.rect.height')
            geometry="${x},${y} ${width}x${height}"

            grim -g "$geometry" "$filename" && finalize_screenshot
        else
            notify-send "Screenshot Cancelled" "No window selected"
        fi
        ;;

    *)
        notify-send "Screenshot Cancelled" "No valid option selected"
        ;;
esac
