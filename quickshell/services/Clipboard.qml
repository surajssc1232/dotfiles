pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Clipboard history, kept by the shell itself.
//
// The usual answer here is cliphist, and your session already tries to start
// one — but the binary is not installed, so nothing has ever been recorded.
// Watching wl-paste directly means the history lives in this config with
// everything else, and needs no package added to the system.
//
// Entries are separated by an ASCII record separator rather than a newline,
// because the interesting things people copy are usually several lines long.
Singleton {
	id: root

	property var entries: []

	readonly property int limit: Config.clipboardLimit

	// A one-line stand-in for an entry, for the list. Runs of whitespace
	// collapse so a copied paragraph does not become a row of blanks.
	function preview(text: string): string {
		const flat = text.replace(/\s+/g, " ").trim();
		return flat.length > 160 ? flat.slice(0, 160) + "…" : flat;
	}

	function describe(text: string): string {
		const lines = text.split("\n").length;
		const chars = text.length + (text.length === 1 ? " character" : " characters");
		return lines > 1 ? lines + " lines · " + chars : chars;
	}

	function add(text: string) {
		if (!Config.clipboardHistory) return;
		if (!text || !text.trim()) return;
		// Enormous pastes are someone moving a file through the clipboard, not
		// something they will ever want to pick out of a list.
		if (text.length > 64000) return;
		if (root.entries.length > 0 && root.entries[0] === text) return;

		root.entries = [text]
			.concat(root.entries.filter(e => e !== text))
			.slice(0, root.limit);
		saveDelay.restart();
	}

	function copy(text: string) {
		// Passed as an argument rather than through a shell, so nothing in the
		// text can be read as syntax.
		Quickshell.execDetached({ command: ["wl-copy", "--", text] });
	}

	function remove(text: string) {
		root.entries = root.entries.filter(e => e !== text);
		saveDelay.restart();
	}

	function clear() {
		root.entries = [];
		store.setText("[]");
	}

	// The watcher fires once per copy. `--list-types` is checked first so
	// password managers that mark their clipboard as sensitive are skipped
	// rather than written to disk.
	Process {
		id: watcher

		running: Config.clipboardHistory
		command: ["wl-paste", "--type", "text", "--watch", "sh", "-c",
			'wl-paste --list-types 2>/dev/null | grep -qi passwordmanagerhint && exit 0; '
			+ 'wl-paste --no-newline --type text; printf "\\036"']

		stdout: SplitParser {
			splitMarker: "\u001e"
			onRead: data => root.add(data)
		}
	}

	// Copying can happen in bursts — dragging through a document, a script
	// echoing into wl-copy — and each one would otherwise be a file write.
	Timer {
		id: saveDelay

		interval: 800
		onTriggered: store.setText(JSON.stringify(root.entries))
	}

	FileView {
		id: store

		path: Quickshell.statePath("clipboard")
		blockLoading: true
		printErrors: false
	}

	Component.onCompleted: {
		try {
			const saved = JSON.parse(store.text().trim() || "[]");
			if (Array.isArray(saved)) root.entries = saved;
		} catch (err) {
			root.entries = [];
		}
	}
}
