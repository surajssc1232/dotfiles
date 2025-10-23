#!/bin/bash
# File to store last workspace stack
STACK_FILE="$HOME/.config/sway/ws_stack"

# Ensure stack file exists
mkdir -p "$(dirname "$STACK_FILE")"
touch "$STACK_FILE"

# Get current workspace
current=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused==true).name')

# Read last workspace from stack
if [[ -s $STACK_FILE ]]; then
    last=$(tail -n 1 "$STACK_FILE")
else
    last=""
fi

# If current workspace is not the last one, add it to stack
if [[ "$current" != "$last" ]]; then
    echo "$current" >> "$STACK_FILE"
fi

# Read stack into array
mapfile -t stack < "$STACK_FILE"

# Compute workspace to switch to (last used before current)
if [[ ${#stack[@]} -ge 2 ]]; then
    target="${stack[-2]}"  # second-to-last workspace
else
    # fallback: just go to next workspace numerically
    mapfile -t workspaces < <(swaymsg -t get_workspaces | jq -r '.[].name')
    for i in "${!workspaces[@]}"; do
        if [[ "${workspaces[$i]}" == "$current" ]]; then
            current_index=$i
            break
        fi
    done
    target="${workspaces[$(( (current_index + 1) % ${#workspaces[@]} ))]}"
fi

# Switch to target workspace
swaymsg workspace "$target"

# Keep stack at most 10 items
tail -n 10 "$STACK_FILE" > "${STACK_FILE}.tmp"
mv "${STACK_FILE}.tmp" "$STACK_FILE"
