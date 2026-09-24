pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Screen colour temperature, via wlsunset over wlr-gamma-control.
//
// wlsunset is built around a day/night cycle and refuses equal high and low
// temperatures, so a constant tint is expressed by pinning sunset to 00:00 and
// sunrise to 23:59: it then stays in "night" all day at the low temperature.
//
// The toggle is deliberately not persisted: night light always starts off on
// login, so a session that ended tinted does not come back tinted.
//
// The temperature is fixed at Config.nightTemp. It is deliberately not
// adjustable while running: wlsunset reads it once at startup, so changing it
// means killing and respawning, which visibly flashes the screen back to
// normal and back again.
Singleton {
	id: root

	property bool enabled: false

	readonly property int temperature: Config.nightTemp

	function setEnabled(on: bool) {
		if (root.enabled === on) return;

		// Set before touching the process: onExited uses this to tell a
		// deliberate stop from a crash.
		root.enabled = on;
		sunset.running = on;
	}

	function toggle() {
		root.setEnabled(!root.enabled);
	}

	Process {
		id: sunset

		command: ["wlsunset",
			"-T", Config.dayTemp.toString(),
			"-t", root.temperature.toString(),
			"-S", "23:59",
			"-s", "00:00",
			"-d", "1"]

		// Gamma is handed back by the compositor when the client goes away, so
		// stopping the process is all that turning this off requires.
		//
		// Reaching here with `enabled` still set means it died on its own —
		// wlsunset refusing to start, or the compositor dropping gamma
		// control — so the toggle is corrected to match reality. A stop we
		// asked for has already cleared `enabled`, and is ignored.
		onExited: if (root.enabled) root.enabled = false
	}
}
