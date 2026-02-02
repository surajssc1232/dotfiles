#!/bin/bash
# ~/.config/waybar/scripts/equalizer.sh

# Check if music is playing
status=$(playerctl status 2>/dev/null)

if [ "$status" = "Playing" ]; then
    # Different equalizer frames for animation
    frames=(
        "▁▃▅▇▅▃▁"
        "▂▄▆█▆▄▂"
        "▃▅▇█▇▅▃"
        "▄▆█▇█▆▄"
        "▅▇█▅█▇▅"
        "▆█▇▃▇█▆"
        "▇█▅▁▅█▇"
        "█▇▃▁▃▇█"
        "▇▅▁▃▁▅▇"
        "▅▃▂▅▂▃▅"
        "▃▁▄▇▄▁▃"
        "▁▂▆█▆▂▁"
    )
    
    # Get current time to create animation cycle
    current_time=$(date +%s)
    frame_index=$((current_time % ${#frames[@]}))
    
    # Just show the animated bars
    echo "{\"text\":\"${frames[$frame_index]}\", \"class\":\"playing\"}"
    
elif [ "$status" = "Paused" ]; then
    echo "{\"text\":\"⏸▄▄▄▄▄▄▄\", \"class\":\"paused\"}"
    
else
    echo "{\"text\":\"\", \"class\":\"stopped\"}"
fi
