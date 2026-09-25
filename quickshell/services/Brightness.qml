pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Display backlight, via brightnessctl.
//
// The sysfs node is root-owned, so writes go through brightnessctl, which
// reaches logind for the active session rather than needing the video group.
Singleton {
	id: root

	// Set by the control centre: polls only while it is on screen, so an
	// external change (a laptop's brightness keys) is picked up when it can
	// actually be seen.
	property bool active: false

	property bool available: false
	property int percent: 0

	// Coalesces a drag into one process per frame-ish; a slider otherwise
	// spawns a process per pixel of travel.
	property int pending: -1

	function set(value: int) {
		if (!root.available) return;
		const clamped = Math.max(1, Math.min(100, Math.round(value)));
		root.percent = clamped;          // optimistic, so the slider tracks
		root.pending = clamped;
		if (!writer.running) root.flush();
	}

	// Asked for by the OSD: the backlight keys run brightnessctl themselves,
	// so a re-read is the only way the shell learns the new value.
	function refresh() {
		if (!writer.running) reader.running = true;
	}

	function flush() {
		if (root.pending < 0) return;
		writer.command = ["brightnessctl", "-q", "set", root.pending + "%"];
		root.pending = -1;
		writer.running = true;
	}

	Process {
		id: writer
		onExited: {
			// A value arrived while this one was in flight: send the latest.
			if (root.pending >= 0) root.flush();
			else reader.running = true;
		}
	}

	Process {
		id: reader

		// "device,class,current,percent,max"
		command: ["brightnessctl", "-m"]

		stdout: StdioCollector {
			onStreamFinished: {
				const parts = text.trim().split("\n")[0]?.split(",") ?? [];
				if (parts.length < 5) {
					root.available = false;
					return;
				}
				root.available = true;
				// Only trust the readback when nothing of ours is in flight,
				// or a stale value would fight the slider mid-drag.
				if (!writer.running && root.pending < 0)
					root.percent = parseInt(parts[3]) || 0;
			}
		}
	}

	Timer {
		interval: 3000
		repeat: true
		running: root.active
		onTriggered: if (!writer.running) reader.running = true
	}

	Component.onCompleted: reader.running = true
}
