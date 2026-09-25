#!/usr/bin/env sh
# Adjusts the backlight and tells the shell to show its readout.
#
# brightnessctl writes sysfs directly, which nothing reports to the shell, so
# the OSD has to be asked for by hand. Usage: brightness.sh up|down [step]
step="${2:-10}"

case "$1" in
	up)   brightnessctl --class=backlight set "+${step}%" >/dev/null ;;
	down) brightnessctl --class=backlight set "${step}%-" >/dev/null ;;
	*)    echo "usage: $0 up|down [step]" >&2; exit 1 ;;
esac

exec qs ipc call osd brightness
