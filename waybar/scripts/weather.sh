#!/usr/bin/env bash
# weather.sh — Waybar JSON with WAQI AQI integration (pure bash version)

# Configuration
CITY="${1:-Bangalore}"
BASE_URL="https://wttr.in/${CITY}"
WAQI_TOKEN="${WAQI_API_KEY:-demo}"  # Set WAQI_API_KEY env variable or use 'demo' (limited)
WAQI_URL="https://api.waqi.info/feed/${CITY}/?token=${WAQI_TOKEN}"

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

# Function to get AQI level
get_aqi_level() {
    local aqi="$1"
    if [[ -z "$aqi" || "$aqi" == "N/A" ]]; then
        echo ""
    elif (( aqi <= 50 )); then
        echo "(Good)"
    elif (( aqi <= 100 )); then
        echo "(Moderate)"
    elif (( aqi <= 150 )); then
        echo "(Unhealthy for Sensitive)"
    elif (( aqi <= 200 )); then
        echo "(Unhealthy)"
    elif (( aqi <= 300 )); then
        echo "(Very Unhealthy)"
    else
        echo "(Hazardous)"
    fi
}

# Function to get UV index level
get_uv_level() {
    local uv="$1"
    if [[ -z "$uv" || "$uv" == "N/A" ]]; then
        echo ""
    elif (( uv <= 2 )); then
        echo "Low"
    elif (( uv <= 5 )); then
        echo "Moderate"
    elif (( uv <= 7 )); then
        echo "High"
    elif (( uv <= 10 )); then
        echo "Very High"
    else
        echo "Extreme"
    fi
}

# Fetch weather JSON data
json=$(curl -s "${BASE_URL}?format=j1" 2>/dev/null)

# Check if we got valid weather data
if [[ -z "$json" ]]; then
    echo '{"text": "N/A", "tooltip": "Weather data unavailable"}'
    exit 0
fi

# Extract weather data using jq
temp=$(echo "$json" | jq -r '.current_condition[0].temp_C // "N/A"' 2>/dev/null)
feels_like=$(echo "$json" | jq -r '.current_condition[0].FeelsLikeC // "N/A"' 2>/dev/null)
humidity=$(echo "$json" | jq -r '.current_condition[0].humidity // "N/A"' 2>/dev/null)
uv=$(echo "$json" | jq -r '.current_condition[0].uvIndex // "N/A"' 2>/dev/null)
wind_speed=$(echo "$json" | jq -r '.current_condition[0].windspeedKmph // "N/A"' 2>/dev/null)
wind_dir=$(echo "$json" | jq -r '.current_condition[0].winddir16Point // "N/A"' 2>/dev/null)
condition=$(echo "$json" | jq -r '.current_condition[0].weatherDesc[0].value // "N/A"' 2>/dev/null)

# Fetch weather emoji
emoji=$(curl -s "${BASE_URL}?format=%c" 2>/dev/null | tr -d '\r' | xargs)
[[ -z "$emoji" ]] && emoji="🌡️"

# Check if we got valid temperature
if [[ "$temp" == "N/A" || "$temp" == "null" || -z "$temp" ]]; then
    echo '{"text": "N/A", "tooltip": "Weather data unavailable"}'
    exit 0
fi

# Fetch AQI data from WAQI
aqi_json=$(curl -s "${WAQI_URL}" 2>/dev/null)
aqi_status=$(echo "$aqi_json" | jq -r '.status // "error"' 2>/dev/null)

# Extract AQI data if available
if [[ "$aqi_status" == "ok" ]]; then
    aqi=$(echo "$aqi_json" | jq -r '.data.aqi // empty' 2>/dev/null)
    pm25=$(echo "$aqi_json" | jq -r '.data.iaqi.pm25.v // empty' 2>/dev/null)
    pm10=$(echo "$aqi_json" | jq -r '.data.iaqi.pm10.v // empty' 2>/dev/null)
    station_name=$(echo "$aqi_json" | jq -r '.data.city.name // empty' 2>/dev/null)
    update_time=$(echo "$aqi_json" | jq -r '.data.time.s // empty' 2>/dev/null)
else
    aqi=""
    pm25=""
    pm10=""
fi

# Main display - show AQI if available
if [[ -n "$aqi" ]]; then
    main="${temp}°C ${emoji} | AQI: ${aqi}"
else
    main="${temp}°C ${emoji}"
fi

# Get UV level description
uv_level=$(get_uv_level "$uv")

# Build tooltip with weather info
tooltip="Temperature: ${temp}°C
Feels Like: ${feels_like}°C
Condition: ${condition}"

# Add UV Index with level
if [[ "$uv" != "N/A" && -n "$uv_level" ]]; then
    tooltip="${tooltip}
UV Index: ${uv} (${uv_level})"
else
    tooltip="${tooltip}
UV Index: ${uv}"
fi

tooltip="${tooltip}
Humidity: ${humidity}%
Wind: ${wind_speed}km/h ${wind_dir}"

# Add AQI info to tooltip if available
if [[ -n "$aqi" || -n "$pm25" ]]; then
    tooltip="${tooltip}

━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -n "$aqi" ]]; then
        aqi_level=$(get_aqi_level "$aqi")
        tooltip="${tooltip}
AQI: ${aqi} ${aqi_level}"
    fi
    
    if [[ -n "$pm25" ]]; then
        tooltip="${tooltip}
PM2.5: ${pm25} μg/m³"
    fi
    
    if [[ -n "$pm10" ]]; then
        tooltip="${tooltip}
PM10: ${pm10} μg/m³"
    fi
    
    if [[ -n "$station_name" ]]; then
        tooltip="${tooltip}
Station: ${station_name}"
    fi
    
    if [[ -n "$update_time" ]]; then
        tooltip="${tooltip}
Updated: ${update_time}"
    fi
else
    tooltip="${tooltip}

━━━━━━━━━━━━━━━━━━━━
AQI: Not available"
fi

# Escape for JSON
main_escaped=$(json_escape "$main")
tooltip_escaped=$(json_escape "$tooltip")

# Output JSON
echo "{\"text\": \"${main_escaped}\", \"tooltip\": \"${tooltip_escaped}\"}"
