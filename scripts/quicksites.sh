#!/bin/bash

HISTORY_FILE="$HOME/.searchsites_history"
HISTORY_LIMIT=50
FUZZEL_LINES=12
DEFAULT_SEARCH="https://www.google.com/search?q="
PINNED=("https://github.com" "https://youtube.com")

# Load recent searches if history exists
choices=""
[[ -f "$HISTORY_FILE" && -s "$HISTORY_FILE" ]] && choices=$(tac "$HISTORY_FILE")

# Combine pinned + history for Fuzzel
combined=$(printf "%s\n%s\n" "${PINNED[@]}" "$choices")

# Fuzzel prompt
input=$(echo "$combined" | fuzzel --dmenu --lines=$FUZZEL_LINES --prompt "Search / URL: ")

# Trim spaces
input=$(echo "$input" | xargs)

# Determine URL based on input
get_url() {
    local in="$1"
    case "$in" in
        !g*) q="${in:2}"; echo "${DEFAULT_SEARCH}$(echo $q | sed 's/ /+/g')" ;;
        !k*) q="${in:2}"; echo "https://kagi.com/search?q=$(echo $q | sed 's/ /+/g')" ;;
        !y*) q="${in:2}"; echo "https://www.youtube.com/results?search_query=$(echo $q | sed 's/ /+/g')" ;;
        !gh*) q="${in:3}"; echo "https://github.com/search?q=$(echo $q | sed 's/ /+/g')" ;;
        *) 
            if [[ "$in" =~ \. ]]; then
                url="$in"
                [[ ! "$url" =~ ^https?:// ]] && url="https://$url"
                echo "$url"
            else
                echo "${DEFAULT_SEARCH}$(echo $in | sed 's/ /+/g')"
            fi
            ;;
    esac
}

[[ -n "$input" ]] && url=$(get_url "$input")

# Open in browser
[[ -n "$url" ]] && zen-browser "$url" &> /dev/null &

# Update history
if [[ -n "$input" ]]; then
    grep -vFx "$input" "$HISTORY_FILE" 2>/dev/null > "$HISTORY_FILE.tmp"
    echo "$input" >> "$HISTORY_FILE.tmp"
    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    tail -n $HISTORY_LIMIT "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
fi
