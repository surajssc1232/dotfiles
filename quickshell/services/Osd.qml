pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The transient overlay that says what just changed: volume, mic, backlight,
// or the keyd layer you just entered.
//
// Volume arrives on its own — the keys go through wpctl, and Pipewire reports
// the change to us. The backlight does not: those keys run brightnessctl
// directly, and nothing tells the shell, so scripts/brightness.sh nudges us
// over IPC after it adjusts.
Singleton {
	id: root

	// "volume" | "mic" | "brightness" | "layer"
	property string kind: ""
	property bool shown: false

	readonly property int holdFor: 900

	function show(what: string) {
		root.kind = what;
		root.shown = true;
		hold.restart();
	}

	Timer {
		id: hold

		interval: root.holdFor
		onTriggered: root.shown = false
	}

	// Pipewire reports every device's volume as it discovers it at startup,
	// which would flash the OSD across the screen on login.
	property bool ready: false

	Timer {
		interval: 2500
		running: true
		onTriggered: root.ready = true
	}

	Connections {
		target: Audio.sink?.audio ?? null
		enabled: root.ready

		function onVolumeChanged(): void { root.show("volume"); }
		function onMutedChanged(): void { root.show("volume"); }
	}

	Connections {
		target: Audio.source?.audio ?? null
		enabled: root.ready

		function onMutedChanged(): void { root.show("mic"); }
	}

	// Entering a layer is worth announcing; leaving it just takes the OSD away
	// rather than replacing it with a second flash.
	Connections {
		target: Keyd
		enabled: root.ready

		function onLayersChanged(): void {
			if (Keyd.active) root.show("layer");
			else if (root.kind === "layer") root.shown = false;
		}
	}

	IpcHandler {
		target: "osd"

		function brightness(): void {
			Brightness.refresh();
			root.show("brightness");
		}

		function volume(): void {
			root.show("volume");
		}

		// For scripting and for checking the thing works without staring at
		// the screen waiting for a 900ms flash.
		function state(): string {
			return (root.shown ? "showing " : "hidden ") + (root.kind || "-");
		}
	}
}
