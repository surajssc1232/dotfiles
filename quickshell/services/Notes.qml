pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A single scratchpad, toggled from a keybind and saved as you type.
//
// Kept in the state directory rather than the config: the dotfiles repo is
// synced to GitHub every 15 minutes, and a scratchpad is exactly where a
// password or a phone number gets pasted.
Singleton {
	id: root

	property bool shown: false
	property string text: ""
	property bool loaded: false

	function toggle() {
		root.shown = !root.shown;
	}

	function edit(value: string) {
		root.text = value;
		save.restart();
	}

	FileView {
		id: file

		path: Quickshell.statePath("notes.md")
		printErrors: false
		blockLoading: true

		onLoaded: {
			root.text = file.text();
			root.loaded = true;
		}
		onLoadFailed: root.loaded = true
	}

	// Written shortly after typing stops, and again whenever it closes.
	Timer {
		id: save
		interval: 600
		onTriggered: file.setText(root.text)
	}

	onShownChanged: if (!root.shown && save.running) {
		save.stop();
		file.setText(root.text);
	}

	// `qs ipc call notes toggle`
	IpcHandler {
		target: "notes"

		function toggle(): void { root.toggle(); }
		function open(): void { root.shown = true; }
		function close(): void { root.shown = false; }
	}
}
