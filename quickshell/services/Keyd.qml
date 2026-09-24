pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which keyd layers are held down right now.
//
// keyd knows this and nothing else does: `keyd listen` is the daemon's own
// event stream, one line per change — "+layer", "-layer", or "/layout" for a
// layout switch. Its socket is root-only, and deliberately so, because `keyd
// bind` can install a command() binding that keyd runs as root. So a small
// system service reads that stream and publishes the current set to one
// world-readable file; this watches the file. Nothing travels back the other
// way, and the shell never touches the socket.
//
// With the service not installed the file is simply absent, the read fails
// quietly, and the indicator stays hidden.
Singleton {
	id: root

	readonly property string statePath: "/run/keyd-layers"

	// Active layer names, in the order they were entered.
	property var layers: []

	readonly property bool active: root.layers.length > 0
	readonly property string label: root.layers.join(" · ")

	function parse(text: string) {
		root.layers = (text ?? "").trim().split(/\s+/).filter(name => name.length > 0);
	}

	FileView {
		id: file

		path: root.statePath
		watchChanges: true
		printErrors: false

		onFileChanged: file.reload()
		onLoaded: root.parse(file.text())
		// The publisher removes the file when it stops, which is the same
		// thing as "no layer is held".
		onLoadFailed: root.layers = []
	}

	// Readable from a script: `qs ipc call keyd layers` prints what is held.
	IpcHandler {
		target: "keyd"

		function layers(): string {
			return root.active ? root.layers.join(" ") : "(none)";
		}
	}
}
