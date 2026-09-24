pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// CPU power profiles, via power-profiles-daemon.
//
// powerprofilesctl has no watch mode, so the value is re-read when it can
// actually have changed: on opening the menu, after setting it, and whenever
// the machine moves on or off mains — the daemon drops out of performance by
// itself when unplugged.
Singleton {
	id: root

	property bool active: false

	property bool available: false
	property string profile: ""
	property var profiles: []
	// power-profiles-daemon reports this when firmware refuses a profile.
	property string degraded: ""

	readonly property var icons: ({
		"performance": "\uf135",   // rocket
		"balanced": "\uf0e4",      // dashboard
		"power-saver": "\uf06c"    // leaf
	})

	readonly property var titles: ({
		"performance": "Performance",
		"balanced": "Balanced",
		"power-saver": "Power saver"
	})

	function icon(id: string): string {
		return root.icons[id] ?? "\uf0e4";
	}

	function title(id: string): string {
		return root.titles[id] ?? id;
	}

	function set(id: string) {
		if (!root.available || id === root.profile) return;
		root.profile = id;             // optimistic; the re-read corrects it
		setter.command = ["powerprofilesctl", "set", id];
		setter.running = true;
	}

	function refresh() {
		if (!lister.running) lister.running = true;
	}

	Process {
		id: setter
		onExited: root.refresh()
	}

	Process {
		id: lister

		// One call for both the list and the active entry: the active one is
		// the line marked with an asterisk.
		command: ["powerprofilesctl", "list"]

		stdout: StdioCollector {
			onStreamFinished: {
				const found = [];
				let current = "";
				let degraded = "";

				for (const line of text.split("\n")) {
					const m = line.match(/^(\*?)\s*([a-z-]+):\s*$/);
					if (m) {
						found.push(m[2]);
						if (m[1] === "*") current = m[2];
						continue;
					}
					const d = line.match(/^\s*Degraded:\s*(.*)$/);
					// "no" is the healthy case and not worth reporting.
					if (d && d[1].trim() && d[1].trim() !== "no")
						degraded = d[1].trim();
				}

				root.available = found.length > 0;
				root.profiles = found;
				if (current) root.profile = current;
				root.degraded = degraded;
			}
		}
	}

	// Unplugging is exactly when the daemon changes profile behind our back.
	Connections {
		target: UPower
		function onOnBatteryChanged() { root.refresh(); }
	}

	Timer {
		interval: 15000
		repeat: true
		running: root.active
		onTriggered: root.refresh()
	}

	Component.onCompleted: root.refresh()
}
