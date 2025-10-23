
#!/usr/bin/env bash
# weather.sh — Waybar JSON with emojis + escaped tooltip

CITY="${1:-Mathura}"
BASE_URL="https://wttr.in/${CITY}"

# Fetch temperature + emoji
main=$(curl -s "${BASE_URL}?format=%t+%c" | sed 's/+//g' | tr -d '\r' | xargs)

# Fetch details for tooltip
details=$(curl -s "${BASE_URL}?format=UV:%U|Humidity:%h|Condition:%C|Wind:%w" | tr -d '\r')

# Replace pipe with escaped newline
details=$(echo "$details" | sed 's/|/\\n/g')

# Escape quotes and backslashes
main=$(echo "$main" | sed 's/\\/\\\\/g; s/"/\\"/g')
details=$(echo "$details" | sed 's/\\/\\\\/g; s/"/\\"/g')

# Fallback
if [[ -z "$main" || "$main" == *"Unknown location"* ]]; then
    echo '{"text": "N/A", "tooltip": "Weather data unavailable"}'
else
    echo "{\"text\": \"${main}\", \"tooltip\": \"${details}\"}"
fi
