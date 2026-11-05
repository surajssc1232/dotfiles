pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Screen colour temperature, via wlsunset over wlr-gamma-control.
//
// wlsunset is built around a day/night cycle and refuses equal high and low
// temperatures, so a constant tint is expressed by pinning sunset to 00:00 and
// sunrise to 23:59: it then stays in "night" all day at the low temperature.
//
// The toggle and the temperature are persisted, so a session that ended tinted
// comes back tinted, at the same warmth.
//
// wlsunset reads the temperature once at startup, so changing it means killing
// and respawning, which visibly flashes the screen back to normal and back
// again. A new value therefore waits for the steps to settle, so a run of them
// costs one flash rather than one each.
Singleton {
	id: root

	property bool enabled: false

	// Moves as soon as it is asked to, so the readout tracks; wlsunset catches
	// up once it settles.
	property int temperature: Config.nightTemp

	// What the running wlsunset was started with.
	property int applied: 0

	// Set while wlsunset is being stopped only to start it again: onExited uses
	// this to tell the respawn from a crash.
	property bool respawning: false

	function clamped(kelvin: real): int {
		const bounded = Math.max(Config.nightTempMin, Math.min(Config.nightTempMax, kelvin));
		return Math.round(bounded / 100) * 100;
	}

	function setTemperature(kelvin: real) {
		const next = root.clamped(kelvin);
		if (root.temperature === next) return;
		root.temperature = next;
		settle.restart();
	}

	function step(dir: int) {
		root.setTemperature(root.temperature + dir * Config.nightTempStep);
	}

	function setEnabled(on: bool) {
		if (root.enabled === on) return;

		// Set before touching the process: onExited uses this to tell a
		// deliberate stop from a crash.
		root.enabled = on;
		sunset.running = on;
		Persist.set("nightLight", on);
	}

	function toggle() {
		root.setEnabled(!root.enabled);
	}

	Timer {
		id: settle

		interval: 300
		onTriggered: {
			Persist.set("nightTemp", root.temperature);
			if (sunset.running && root.temperature !== root.applied) {
				root.respawning = true;
				sunset.running = false;
			}
		}
	}

	Process {
		id: sunset

		// setpriv ties wlsunset's life to this shell's. Without it, a shell that
		// is killed or crashes leaves wlsunset running, still holding gamma
		// control: the next shell shows the toggle off over a tinted screen, and
		// its own wlsunset is refused gamma control, so it cannot change anything.
		command: ["setpriv", "--pdeathsig", "TERM", "wlsunset",
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
		//
		// A respawn is the exception: the old instance has to be gone before the
		// new one starts, or the new one is refused gamma control.
		onExited: {
			if (root.respawning) {
				root.respawning = false;
				if (root.enabled) sunset.running = true;
			} else if (root.enabled) {
				root.enabled = false;
			}
		}

		onStarted: root.applied = root.temperature
	}

	// wlsunset is spawned here the same way the toggle would, so a restored
	// "on" goes through exactly one code path.
	Component.onCompleted: {
		root.temperature = root.clamped(Persist.get("nightTemp", Config.nightTemp));
		root.setEnabled(Persist.get("nightLight", false));
	}
}
