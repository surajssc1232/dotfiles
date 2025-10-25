waybar &

swww-daemon & disown

# trying to rrestart the xdg-desktop-portal-wlr
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=mango XDG_SESSION_TYPE=wayland


/usr/sbin/xwayland-satellite :11 &



dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots
# The next line of command is not necessary. It is only to avoid some situations where it cannot start automatically
/usr/lib/xdg-desktop-portal-wlr &


# keep clipboard content
wl-clip-persist --clipboard regular --reconnect-tries 0 &

# clipboard content manager
wl-paste --type text --watch cliphist store & 

wlsunset -T 3501 -t 3500 &

# xwayland dpi scale
echo "Xft.dpi: 140" | xrdb -merge #dpi缩放
gsettings set org.gnome.desktop.interface text-scaling-factor 1
