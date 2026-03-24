#!/usr/bin/env bash

# File to store your search history
HISTORY_FILE="$HOME/.cache/web_search_history"
touch "$HISTORY_FILE"

# 1. Get unique recent searches (newest first)
# 'tac' reverses the file, 'awk' removes duplicates while keeping order
RECENT_SEARCHES=$(tac "$HISTORY_FILE" | awk '!seen[$0]++' | head -n 15)

# 2. Show the menu in fuzzel
# We use --dmenu to treat input as a list selection or a new string
QUERY=$(echo -e "$RECENT_SEARCHES" | fuzzel --dmenu --placeholder "Search or select recent..." --width 60)

# 3. Execute and Log
if [ -n "$QUERY" ]; then
    # Save the search to our history file
    echo "$QUERY" >> "$HISTORY_FILE"
    
    # Define search engine
    SEARCH_URL="https://www.google.com/search?q="
    
    # Launch Helium with the query
    helium "${SEARCH_URL}${QUERY}"
fi
