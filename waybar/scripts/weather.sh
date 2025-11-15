#!/run/current-system/sw/bin/bash

# weather.sh — Waybar JSON with WAQI AQI integration

# Configuration
CITY="Mathura"
BASE_URL="https://wttr.in/${CITY}"
WAQI_TOKEN="ae2f9b9c286f882b46c8a38430436c303ad23f67"

# WAQI URLs
WAQI_URL="https://api.waqi.info/feed/${CITY}/?token=${WAQI_TOKEN}"
WAQI_SEARCH_URL="https://api.waqi.info/search/?keyword=${CITY}&token=${WAQI_TOKEN}"

RETRY_COUNT=3
RETRY_DELAY=2

# Function to escape JSON strings
json_escape() {
    local string="$1"
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    string="${string//$'\n'/\\n}"
    string="${string//$'\r'/}"
    string="${string//$'\t'/\\t}"
    echo "$string"
}

# Function to get weather icon based on condition code
get_weather_icon() {
    local condition="$1"
    local code=$(echo "$json" | jq -r '.current_condition[0].weatherCode // empty' 2>/dev/null)
    
    case "$code" in
        113) echo "☀" ;;  # Sunny/Clear
        116) echo "🌤" ;;  # Partly cloudy
        119) echo "☁" ;;  # Cloudy
        122) echo "☁" ;;  # Overcast
        143|248|260) echo "🌫" ;;  # Fog/Mist
        176|263|266|293|296) echo "🌦" ;;  # Light rain
        179|182|185|281|284|311|314|317|350|362|365|374|377) echo "🌨" ;;  # Snow/Sleet
        200|386|389) echo "⛈" ;;  # Thunderstorm
        227|230|329|332|335|338|371) echo "❄" ;;  # Heavy snow
        299|302|305|308|356|359) echo "🌧" ;;  # Rain
        392|395) echo "🌨" ;;  # Heavy snow
        *) 
            case "${condition,,}" in
                *clear*|*sunny*) echo "☀" ;;
                *partly*|*partial*) echo "🌤" ;;
                *cloud*|*overcast*) echo "☁" ;;
                *rain*|*drizzle*) echo "🌧" ;;
                *storm*|*thunder*) echo "⛈" ;;
                *snow*) echo "❄" ;;
                *fog*|*mist*) echo "🌫" ;;
                *) echo "☀" ;;
            esac
            ;;
    esac
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

# Function to fetch URL with retries
fetch_with_retry() {
    local url="$1"
    local timeout="${2:-10}"
    local result=""
    
    for ((i=1; i<=RETRY_COUNT; i++)); do
        result=$(curl -s --max-time "$timeout" --connect-timeout 5 "$url" 2>/dev/null)
        if [[ -n "$result" && "$result" != "null" ]]; then
            echo "$result"
            return 0
        fi
        [[ $i -lt $RETRY_COUNT ]] && sleep "$RETRY_DELAY"
    done
    
    return 1
}

# Function to validate location matches requested city
validate_location() {
    local station_name="$1"
    local requested_city="$2"
    
    local station_lower="${station_name,,}"
    local city_lower="${requested_city,,}"
    
    # Check if station name contains the requested city
    if [[ "$station_lower" == *"$city_lower"* ]]; then
        return 0
    fi
    
    # For Indian cities, check without state
    local station_first_part="${station_name%%,*}"
    station_first_part="${station_first_part,,}"
    
    if [[ "$station_first_part" == "$city_lower" ]]; then
        return 0
    fi
    
    return 1
}

# Fetch weather JSON data with retries
json=$(fetch_with_retry "${BASE_URL}?format=j1" 10)

if [[ -z "$json" ]]; then
    echo '{"text": "☀ Loading...", "tooltip": "Fetching weather data..."}'
    exit 0
fi

# Extract weather data using jq
temp=$(echo "$json" | jq -r '.current_condition[0].temp_C // empty' 2>/dev/null)
feels_like=$(echo "$json" | jq -r '.current_condition[0].FeelsLikeC // empty' 2>/dev/null)
humidity=$(echo "$json" | jq -r '.current_condition[0].humidity // empty' 2>/dev/null)
uv=$(echo "$json" | jq -r '.current_condition[0].uvIndex // empty' 2>/dev/null)
wind_speed=$(echo "$json" | jq -r '.current_condition[0].windspeedKmph // empty' 2>/dev/null)
wind_dir=$(echo "$json" | jq -r '.current_condition[0].winddir16Point // empty' 2>/dev/null)
condition=$(echo "$json" | jq -r '.current_condition[0].weatherDesc[0].value // empty' 2>/dev/null)

# Get weather icon
icon=$(get_weather_icon "$condition")

# Validate critical data
if [[ -z "$temp" ]]; then
    echo '{"text": "☀ Loading...", "tooltip": "Weather data loading..."}'
    exit 0
fi

# Fetch AQI data from WAQI
aqi_json=$(fetch_with_retry "${WAQI_URL}" 8)
aqi_status=$(echo "$aqi_json" | jq -r '.status // "error"' 2>/dev/null)

# Initialize AQI variables
aqi=""
pm25=""
pm10=""
station_name=""
update_time=""

# Extract AQI data if available and validate location
if [[ "$aqi_status" == "ok" ]]; then
    station_name=$(echo "$aqi_json" | jq -r '.data.city.name // empty' 2>/dev/null)
    
    # Validate that the station matches our requested city
    if validate_location "$station_name" "$CITY"; then
        aqi=$(echo "$aqi_json" | jq -r '.data.aqi // empty' 2>/dev/null)
        pm25=$(echo "$aqi_json" | jq -r '.data.iaqi.pm25.v // empty' 2>/dev/null)
        pm10=$(echo "$aqi_json" | jq -r '.data.iaqi.pm10.v // empty' 2>/dev/null)
        update_time=$(echo "$aqi_json" | jq -r '.data.time.s // empty' 2>/dev/null)
    else
        # Location mismatch - try search API
        search_json=$(fetch_with_retry "${WAQI_SEARCH_URL}" 8)
        search_status=$(echo "$search_json" | jq -r '.status // "error"' 2>/dev/null)
        
        if [[ "$search_status" == "ok" ]]; then
            station_uid=$(echo "$search_json" | jq -r '.data[0].uid // empty' 2>/dev/null)
            
            if [[ -n "$station_uid" ]]; then
                station_url="https://api.waqi.info/feed/@${station_uid}/?token=${WAQI_TOKEN}"
                aqi_json=$(fetch_with_retry "${station_url}" 8)
                aqi_status=$(echo "$aqi_json" | jq -r '.status // "error"' 2>/dev/null)
                
                if [[ "$aqi_status" == "ok" ]]; then
                    aqi=$(echo "$aqi_json" | jq -r '.data.aqi // empty' 2>/dev/null)
                    pm25=$(echo "$aqi_json" | jq -r '.data.iaqi.pm25.v // empty' 2>/dev/null)
                    pm10=$(echo "$aqi_json" | jq -r '.data.iaqi.pm10.v // empty' 2>/dev/null)
                    station_name=$(echo "$aqi_json" | jq -r '.data.city.name // empty' 2>/dev/null)
                    update_time=$(echo "$aqi_json" | jq -r '.data.time.s // empty' 2>/dev/null)
                fi
            fi
        fi
    fi
fi

# Main display - show AQI if available
if [[ -n "$aqi" ]]; then
    main="${temp}°C ${icon} | AQI: ${aqi}"
else
    main="${temp}°C ${icon}"
fi

# Get UV level description
uv_level=$(get_uv_level "$uv")

# Build tooltip with weather info
tooltip="Temperature: ${temp}°C"

[[ -n "$feels_like" ]] && tooltip="${tooltip}
Feels Like: ${feels_like}°C"

[[ -n "$condition" ]] && tooltip="${tooltip}
Condition: ${condition}"

# Add UV Index with level
if [[ -n "$uv" ]]; then
    if [[ -n "$uv_level" ]]; then
        tooltip="${tooltip}
UV Index: ${uv} (${uv_level})"
    else
        tooltip="${tooltip}
UV Index: ${uv}"
    fi
fi

[[ -n "$humidity" ]] && tooltip="${tooltip}
Humidity: ${humidity}%"

if [[ -n "$wind_speed" && -n "$wind_dir" ]]; then
    tooltip="${tooltip}
Wind: ${wind_speed}km/h ${wind_dir}"
elif [[ -n "$wind_speed" ]]; then
    tooltip="${tooltip}
Wind: ${wind_speed}km/h"
fi

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
fi

# Escape for JSON
main_escaped=$(json_escape "$main")
tooltip_escaped=$(json_escape "$tooltip")

# Build final output
output="{\"text\": \"${main_escaped}\", \"tooltip\": \"${tooltip_escaped}\"}"

# Output JSON
echo "$output"
