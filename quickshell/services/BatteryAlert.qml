pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Warns before the battery runs out.
//
// Nothing on this system did: the bar turns the icon red under 15%, which is
// only useful if you happen to be looking at it. These go through notify-send
// rather than being injected into the toast stack directly, because the shell
// owns the notification server — sending one the ordinary way means it lands
// in history with everything else and obeys do-not-disturb.
Singleton {
	id: root

	readonly property var battery: UPower.displayDevice
	readonly property bool laptop: root.battery?.isLaptopBattery ?? false
	readonly property int percent: root.battery ? Math.round(root.battery.percentage * 100) : 100
	readonly property bool discharging: root.battery?.state === UPowerDeviceState.Discharging

	// Descending, so the lowest matching threshold is the one that fires.
	readonly property var levels: [20, 10, 5]

	// Thresholds below this have already been announced this discharge. Reset
	// on plugging in, so a charge-and-unplug cycle warns again.
	property int floorLevel: 101

	function check() {
		if (!root.laptop) return;

		if (!root.discharging) {
			root.floorLevel = 101;
			return;
		}

		for (const level of root.levels) {
			if (root.percent <= level && root.floorLevel > level) {
				root.floorLevel = level;
				root.announce(level);
				return;
			}
		}
	}

	function announce(level: int) {
		const critical = level <= 5;
		Quickshell.execDetached({
			command: ["notify-send",
				"-u", critical ? "critical" : "normal",
				"-a", "Battery",
				level + "% battery remaining",
				critical
					? "Plug in now."
					: "Time to find a charger."]
		});
	}

	onPercentChanged: root.check()
	onDischargingChanged: root.check()

	// UPower can take a moment to report a real percentage at startup, and a
	// laptop woken at 8% should still be told about it.
	Timer {
		interval: 20000
		running: true
		repeat: true
		onTriggered: root.check()
	}
}
