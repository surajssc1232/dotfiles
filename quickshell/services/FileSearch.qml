pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// File lookup for the launcher's / mode: recently used files when nothing has
// been typed, an fd search under $HOME once something has.
//
// Searching starts a process, so it is debounced — typing "report" would
// otherwise start six searches and race their results into the list, and the
// one that answers last wins rather than the one that asked last.
Singleton {
	id: root

	property string query: ""
	property var results: []
	property bool searching: false

	readonly property int limit: 40

	// A search asked for while one is still running. fd is fast, but not so
	// fast that a fast typist cannot outrun it, and restarting a Process that
	// is still going is how launches get silently dropped.
	property bool pending: false

	readonly property string home: Quickshell.env("HOME")

	// Symlinks are deliberately not followed, and these are deliberately never
	// entered. A wine prefix contains dosdevices/z: pointing at /, so a search
	// that follows links walks the entire filesystem once per prefix: the same
	// query took 75 seconds with --follow and half a second without it.
	readonly property var prune: [
		".git", "node_modules", ".cache", "dosdevices", "drive_c",
		".steam", "Steam", "Prefixes", ".venv", "target", "result"
	]

	readonly property var pruned: {
		const out = [];
		for (const dir of root.prune) out.push("--exclude", dir);
		return out;
	}

	function shorten(path: string): string {
		return path.startsWith(root.home) ? "~" + path.slice(root.home.length) : path;
	}

	function directory(path: string): string {
		const at = path.lastIndexOf("/");
		return at <= 0 ? "/" : root.shorten(path.slice(0, at));
	}

	function name(path: string): string {
		return path.slice(path.lastIndexOf("/") + 1);
	}

	function open(path: string) {
		Quickshell.execDetached({ command: ["xdg-open", path] });
	}

	function reveal(path: string) {
		Quickshell.execDetached({
			command: ["xdg-open", path.slice(0, path.lastIndexOf("/")) || "/"]
		});
	}

	onQueryChanged: {
		if (!root.query) {
			root.results = [];
			root.searching = false;
			debounce.stop();
			return;
		}
		debounce.restart();
	}

	Timer {
		id: debounce

		interval: 180
		onTriggered: root.run()
	}

	function run() {
		if (!root.query) return;

		if (finder.running) {
			root.pending = true;
			return;
		}

		root.searching = true;
		finder.command = ["fd", "--type", "f", "--hidden",
			"--max-results", root.limit.toString()]
			.concat(root.pruned)
			.concat(["--", root.query, root.home]);
		finder.running = true;
	}

	Process {
		id: finder

		stdout: StdioCollector {
			onStreamFinished: {
				root.results = this.text.trim().split("\n").filter(line => line !== "");
				root.searching = false;
			}
		}

		onExited: {
			root.searching = false;
			if (!root.pending) return;
			root.pending = false;
			root.run();
		}
	}

	// ---- recently used ----
	//
	// The freedesktop bookmark file every GTK and Qt file dialog writes to.
	// Read on demand rather than watched: it changes constantly and nothing
	// here needs to know until the list is actually being looked at.
	readonly property var recent: {
		const out = [];
		const seen = ({});
		const text = recentFile.text();
		if (!text) return out;

		const pattern = /href="file:\/\/([^"]*)"[^>]*visited="([^"]*)"/g;
		let match;
		while ((match = pattern.exec(text)) !== null) {
			let path;
			try {
				path = decodeURIComponent(match[1]);
			} catch (err) {
				// A malformed percent-escape is not worth losing the list over.
				path = match[1];
			}
			if (seen[path]) continue;
			seen[path] = true;
			out.push({ path: path, visited: match[2] });
		}

		// The timestamps are ISO 8601 and fixed width, so they sort as strings.
		out.sort((a, b) => b.visited.localeCompare(a.visited));
		return out.slice(0, root.limit).map(e => e.path);
	}

	function refreshRecent() {
		recentFile.reload();
	}

	FileView {
		id: recentFile

		path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
		blockLoading: true
		printErrors: false
	}
}
