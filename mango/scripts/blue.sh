#!/usr/bin/env bash
#   __                    _       _     _            _              _   _
#  / _|_   _ __________ __| |     | |__ | |_   _  ___| |_ ___   ___ | |_| |__
# | |_| | | |_  /_  / _ | |_____| '_ \| | | | |/ _ \ __/ _ \ / _ \| __| '_ \
# |  _| |_| |/ / / /  __/ |_____| |_) | | |_| |  __/ || (_) | (_) | |_| | | |
# |_|  \__,_/___/___\___|_|     |_.__/|_|\__,_|\___|\__\___/ \___/ \__|_| |_|
#
# Author: Nick Clyde (clydedroid) - Original rofi version
# Adapted for fuzzel
#
# A script that generates a fuzzel menu that uses bluetoothctl to
# connect to bluetooth devices and display status info.
#
# Depends on:
#   fuzzel, bluez-utils (contains bluetoothctl), bc

# Constants
divider="---------"
goback="← Back"

power_on() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        return 0
    else
        return 1
    fi
}

toggle_power() {
    if power_on; then
        bluetoothctl power off
        show_menu
    else
        if rfkill list bluetooth | grep -q 'blocked: yes'; then
            rfkill unblock bluetooth && sleep 3
        fi
        bluetoothctl power on
        show_menu
    fi
}

scan_on() {
    if bluetoothctl show | grep -q "Discovering: yes"; then
        echo "Scan: on"
        return 0
    else
        echo "Scan: off"
        return 1
    fi
}

toggle_scan() {
    if scan_on; then
        kill $(pgrep -f "bluetoothctl --timeout 5 scan on") 2>/dev/null
        bluetoothctl scan off
        show_menu
    else
        bluetoothctl --timeout 5 scan on &
        notify-send "Bluetooth" "Scanning for devices..." 2>/dev/null || echo "Scanning..."
        show_menu
    fi
}

pairable_on() {
    if bluetoothctl show | grep -q "Pairable: yes"; then
        echo "Pairable: on"
        return 0
    else
        echo "Pairable: off"
        return 1
    fi
}

toggle_pairable() {
    if pairable_on; then
        bluetoothctl pairable off
        show_menu
    else
        bluetoothctl pairable on
        show_menu
    fi
}

discoverable_on() {
    if bluetoothctl show | grep -q "Discoverable: yes"; then
        echo "Discoverable: on"
        return 0
    else
        echo "Discoverable: off"
        return 1
    fi
}

toggle_discoverable() {
    if discoverable_on; then
        bluetoothctl discoverable off
        show_menu
    else
        bluetoothctl discoverable on
        show_menu
    fi
}

device_connected() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Connected: yes"; then
        return 0
    else
        return 1
    fi
}

toggle_connection() {
    if device_connected "$1"; then
        bluetoothctl disconnect "$1"
        result=$?
        if [ $result -eq 0 ]; then
            notify-send "Bluetooth" "Disconnected from device" 2>/dev/null
        fi
        device_menu "$device"
    else
        bluetoothctl connect "$1"
        result=$?
        if [ $result -eq 0 ]; then
            notify-send "Bluetooth" "Connected to device" 2>/dev/null
        fi
        device_menu "$device"
    fi
}

device_paired() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Paired: yes"; then
        echo "Paired: yes"
        return 0
    else
        echo "Paired: no"
        return 1
    fi
}

toggle_paired() {
    if device_paired "$1"; then
        bluetoothctl remove "$1"
        result=$?
        if [ $result -eq 0 ]; then
            notify-send "Bluetooth" "Device removed" 2>/dev/null
        fi
        show_menu  
    else
        bluetoothctl pair "$1"
        result=$?
        if [ $result -eq 0 ]; then
            notify-send "Bluetooth" "Device paired" 2>/dev/null
        fi
        device_menu "$device"
    fi
}

device_trusted() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Trusted: yes"; then
        echo "Trusted: yes"
        return 0
    else
        echo "Trusted: no"
        return 1
    fi
}

toggle_trust() {
    if device_trusted "$1"; then
        bluetoothctl untrust "$1"
        device_menu "$device"
    else
        bluetoothctl trust "$1"
        device_menu "$device"
    fi
}

print_status() {
    if power_on; then
        printf ''

        paired_devices_cmd="devices Paired"
        if command -v bc >/dev/null 2>&1; then
            if (( $(echo "$(bluetoothctl version | cut -d ' ' -f 2) < 5.65" | bc -l) )); then
                paired_devices_cmd="paired-devices"
            fi
        else
            paired_devices_cmd="paired-devices"
        fi

        mapfile -t paired_devices < <(bluetoothctl $paired_devices_cmd | grep Device | cut -d ' ' -f 2)
        counter=0

        for device in "${paired_devices[@]}"; do
            if device_connected "$device"; then
                device_alias=$(bluetoothctl info "$device" | grep "Alias" | cut -d ' ' -f 2-)

                if [ $counter -gt 0 ]; then
                    printf ", %s" "$device_alias"
                else
                    printf " %s" "$device_alias"
                fi

                ((counter++))
            fi
        done
        printf "\n"
    else
        echo ""
    fi
}

device_menu() {
    device=$1

    device_name=$(echo "$device" | cut -d ' ' -f 3-)
    mac=$(echo "$device" | cut -d ' ' -f 2)

    if device_connected "$mac"; then
        connected="● Connected: yes"
    else
        connected="○ Connected: no"
    fi
    paired=$(device_paired "$mac")
    trusted=$(device_trusted "$mac")
    
    paired_display="◉ $paired"
    trusted_display="◈ $trusted"
    
    options="$connected\n$paired_display\n$trusted_display\n$divider\n$goback\n✕ Exit"

    chosen="$(echo -e "$options" | fuzzel --dmenu --prompt="$device_name: " --width=40 --lines=10)"

    case "$chosen" in
        "" | "$divider")
            exit 0
            ;;
        "$connected")
            toggle_connection "$mac"
            ;;
        "$paired_display")
            toggle_paired "$mac"
            ;;
        "$trusted_display")
            toggle_trust "$mac"
            ;;
        "$goback")
            show_menu
            ;;
        "✕ Exit")
            exit 0
            ;;
    esac
}

show_menu() {
    if power_on; then
        power="▲ Power: on"

        devices=$(bluetoothctl devices | grep Device | cut -d ' ' -f 3-)
        
        if [ -n "$devices" ]; then
            devices=$(echo "$devices" | sed 's/^/◦ /')
        fi

        scan=$(scan_on)
        pairable=$(pairable_on)
        discoverable=$(discoverable_on)

        scan_display="◈ $scan"
        pairable_display="◉ $pairable"
        discoverable_display="◎ $discoverable"

        if [ -n "$devices" ]; then
            options="$devices\n$divider\n$power\n$scan_display\n$pairable_display\n$discoverable_display\n✕ Exit"
        else
            options="$divider\n$power\n$scan_display\n$pairable_display\n$discoverable_display\n✕ Exit"
        fi
    else
        power="▼ Power: off"
        options="$power\n✕ Exit"
    fi

    chosen="$(echo -e "$options" | fuzzel --dmenu --prompt="Bluetooth: " --width=40 --lines=15)"

    case "$chosen" in
        "" | "$divider")
            exit 0
            ;;
        "$power")
            toggle_power
            ;;
        "$scan_display")
            toggle_scan
            ;;
        "$discoverable_display")
            toggle_discoverable
            ;;
        "$pairable_display")
            toggle_pairable
            ;;
        "✕ Exit")
            exit 0
            ;;
        *)
            device_name=$(echo "$chosen" | sed 's/^◦ //')
            device=$(bluetoothctl devices | grep "$device_name")
            if [[ $device ]]; then 
                device_menu "$device"
            fi
            ;;
    esac
}

case "$1" in
    --status)
        print_status
        ;;
    *)
        show_menu
        ;;
esac
