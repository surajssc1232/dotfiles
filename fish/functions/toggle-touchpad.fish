function toggle-touchpad
    set driver i2c_hid_acpi
    set dev i2c-ASUE1301:00
    set sysdir /sys/bus/i2c/drivers/$driver
    if test -L "$sysdir/$dev"
        # Device is currently bound → disable it
        echo $dev | sudo tee $sysdir/unbind >/dev/null
        echo "Touchpad disabled"
        notify-send "Touchpad disabled"
    else
        # Device is currently unbound → enable it
        echo $dev | sudo tee $sysdir/bind >/dev/null
        echo "Touchpad enabled"
        notify-send "Touchpad enabled"
    end
end
