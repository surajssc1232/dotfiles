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

	function folder(path: string): string {
		return path.slice(0, path.lastIndexOf("/")) || "/";
	}

	// Asks whatever file manager owns org.freedesktop.FileManager1 to show the
	// file selected in its folder, and falls back to opening the folder in the
	// default handler for inode/directory (nemo, here) when nothing answers.
	function reveal(path: string) {
		const uri = "file://" + encodeURI(path);
		Quickshell.execDetached({ command: ["sh", "-c",
			'gdbus call --session --dest org.freedesktop.FileManager1 '
			+ '--object-path /org/freedesktop/FileManager1 '
			+ '--method org.freedesktop.FileManager1.ShowItems "[\'$1\']" "" '
			+ '>/dev/null 2>&1 || xdg-open "$2"',
			"sh", uri, root.folder(path)] });
	}

	// ---- file operations (right-click menu) ----
	//
	// Plain sh so a failure can say so: each one reports through notify-send
	// instead of failing silently inside a detached process.

	function expand(path: string): string {
		return path.replace(/^~(?=\/|$)/, root.home);
	}

	function sh(script: string, ...args) {
		Quickshell.execDetached({ command: ["sh", "-c",
			script + ' || notify-send -a Files "Could not complete that" "$1"',
			"sh"].concat(args) });
		refresh.restart();
	}

	function copyTo(path: string, dest: string) {
		root.sh('cp -rn -- "$1" "$2"', path, root.expand(dest));
	}

	function moveTo(path: string, dest: string) {
		root.sh('mv -n -- "$1" "$2"', path, root.expand(dest));
	}

	function rename(path: string, newName: string) {
		root.sh('mv -n -- "$1" "$2"', path, root.folder(path) + "/" + newName);
	}

	// The freedesktop trash, written by hand: no gio or trash-put here, and
	// Nemo's own trash reads exactly this layout, so Restore keeps working.
	function trash(path: string) {
		root.sh('t="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"; mkdir -p "$t/files" "$t/info" && '
			+ 'n=$(basename "$1"); d="$n"; i=1; '
			+ 'while [ -e "$t/files/$d" ] || [ -e "$t/info/$d.trashinfo" ]; do d="$n.$i"; i=$((i+1)); done; '
			+ 'printf "[Trash Info]\nPath=%s\nDeletionDate=%s\n" "$(realpath -- "$1")" "$(date +%Y-%m-%dT%H:%M:%S)" > "$t/info/$d.trashinfo" && '
			+ 'mv -- "$1" "$t/files/$d"', path);
	}

	function remove(path: string) {
		root.sh('rm -rf -- "$1"', path);
	}

	Timer {
		id: refresh

		interval: 400
		onTriggered: {
			root.refreshRecent();
			if (root.query) root.run();
		}
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
