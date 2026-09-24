pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One small key/value file for the toggles that should survive a restart.
//
// Theme and wallpaper keep files of their own, because they are read before
// the first frame is drawn and want to be found without parsing anything.
// Everything else lands here, so adding a setting is a get() and a set()
// rather than another FileView and another file.
//
// Volume, Wi-Fi radio, Bluetooth power and screen brightness are deliberately
// absent: PipeWire, NetworkManager, BlueZ and the kernel each remember those
// themselves, and a second copy here would only end up fighting them.
Singleton {
	id: root

	// Left undefined until first use. Singletons are built on demand, so the
	// one asking may well be constructed before this one's Component.onCompleted
	// would have run — whoever arrives first parses the file.
	property var values

	function load() {
		if (root.values !== undefined) return;
		try {
			const parsed = JSON.parse(store.text().trim() || "{}");
			root.values = (parsed && typeof parsed === "object") ? parsed : ({});
		} catch (err) {
			root.values = ({});
		}
	}

	function get(key: string, fallback) {
		root.load();
		return root.values[key] ?? fallback;
	}

	// Written through immediately rather than batched: these change when
	// someone flips a switch, which is rare, and a delayed write is exactly
	// the one that loses the setting if the session ends right after.
	function set(key: string, value) {
		root.load();
		if (root.values[key] === value) return;
		root.values[key] = value;
		store.setText(JSON.stringify(root.values));
	}

	FileView {
		id: store

		path: Quickshell.statePath("settings")
		blockLoading: true
		printErrors: false
	}
}
