function power
    set capacity (cat /sys/class/power_supply/BAT0/capacity)
    set status_bat (cat /sys/class/power_supply/BAT0/status)
    echo "Battery : "$capacity"%"
    echo "Status  : "$status_bat
end
