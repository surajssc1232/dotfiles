pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// External monitor brightness, through the monitor-brightness script.
//
// DDC is slow, so this polls only while the control centre is on screen. That
// is also how a monitor being plugged in or pulled gets noticed.
Singleton {
	id: root

	// Set by the control centre.
	property bool active: false
	onActiveChanged: if (active) refresh()

	property bool available: false
	property int percent: 0
	property int max: 100

	// DDC reads fail now and then with the monitor still attached, and hiding
	// the slider for one of those would make it flicker.
	property int misses: 0
	property int pending: -1

	function set(value: int) {
		if (!root.available) return;
		const clamped = Math.max(0, Math.min(100, Math.round(value)));
		root.percent = clamped;          // optimistic, so the slider tracks
		root.pending = clamped;
		if (!writer.running) root.flush();
	}

	// The monitor-brightness script has already written this value, so there
	// is nothing to read back.
	function report(value: int) {
		root.percent = value;
		root.available = true;
		root.misses = 0;
	}

	function refresh() {
		if (!writer.running) reader.running = true;
	}

	function flush() {
		if (root.pending < 0) return;
		const raw = Math.round(root.pending * root.max / 100);
		writer.command = ["monitor-brightness", "set", String(raw)];
		root.pending = -1;
		writer.running = true;
	}

	Process {
		id: writer
		onExited: {
			// A value arrived while this one was in flight: send the latest.
			if (root.pending >= 0) root.flush();
		}
	}

	Process {
		id: reader

		// "VCP 10 C <current> <max>"
		command: ["monitor-brightness", "get"]

		stdout: StdioCollector {
			onStreamFinished: {
				const match = text.match(/^VCP 10 C (\d+) (\d+)/m);
				if (!match || parseInt(match[2]) <= 0) {
					root.misses++;
					if (root.misses >= 2) root.available = false;
					return;
				}
				root.misses = 0;
				root.available = true;
				root.max = parseInt(match[2]);
				// A stale value would fight the slider mid-drag.
				if (!writer.running && root.pending < 0)
					root.percent = Math.round(parseInt(match[1]) * 100 / root.max);
			}
		}
	}

	Timer {
		interval: 5000
		repeat: true
		running: root.active
		onTriggered: root.refresh()
	}

	Component.onCompleted: reader.running = true
}
