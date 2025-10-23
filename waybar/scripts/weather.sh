#!/usr/bin/env bash
# weather.sh — Waybar JSON (pure bash version)
CITY="${1:-Bangalore}"
BASE_URL="https://wttr.in/${CITY}"

# Function to escape JSON strings
json_escape() {
    local string="$1"
    # Escape backslashes first, then quotes, then newlines and other special chars
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    string="${string//$'\n'/\\n}"
    string="${string//$'\r'/}"
    string="${string//$'\t'/\\t}"
    echo "$string"
}

# Fetch JSON data
json=$(curl -s "${BASE_URL}?format=j1" 2>/dev/null)

# Check if we got valid data
if [[ -z "$json" ]]; then
    echo '{"text": "N/A", "tooltip": "Weather data unavailable"}'
    exit 0
fi

# Extract data using jq
temp=$(echo "$json" | jq -r '.current_condition[0].temp_C // "N/A"' 2>/dev/null)
feels_like=$(echo "$json" | jq -r '.current_condition[0].FeelsLikeC // "N/A"' 2>/dev/null)
humidity=$(echo "$json" | jq -r '.current_condition[0].humidity // "N/A"' 2>/dev/null)
uv=$(echo "$json" | jq -r '.current_condition[0].uvIndex // "N/A"' 2>/dev/null)
wind_speed=$(echo "$json" | jq -r '.current_condition[0].windspeedKmph // "N/A"' 2>/dev/null)
wind_dir=$(echo "$json" | jq -r '.current_condition[0].winddir16Point // "N/A"' 2>/dev/null)
condition=$(echo "$json" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"' 2>/dev/null)

# Fetch emoji
emoji=$(curl -s "${BASE_URL}?format=%c" 2>/dev/null | tr -d '\r' | xargs)
[[ -z "$emoji" ]] && emoji="🌡️"

# Check if we got valid temperature
if [[ "$temp" == "N/A" || "$temp" == "null" || -z "$temp" ]]; then
    echo '{"text": "N/A", "tooltip": "Weather data unavailable"}'
    exit 0
fi

# Main display
main="${temp}°C ${emoji}"

# Build tooltip with newlines
tooltip="Temperature: ${temp}°C
Feels Like: ${feels_like}°C
Condition: ${condition}
UV Index: ${uv}
Humidity: ${humidity}%
Wind: ${wind_speed}km/h ${wind_dir}"

# Escape for JSON
main_escaped=$(json_escape "$main")
tooltip_escaped=$(json_escape "$tooltip")

# Output JSON
echo "{\"text\": \"${main_escaped}\", \"tooltip\": \"${tooltip_escaped}\"}"
