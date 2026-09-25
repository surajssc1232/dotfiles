pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

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

	// Copied images, newest first: [{ path, at }]. Kept as files rather than
	// inline data because a screenshot is megabytes, and the text history is
	// re-read and rewritten far too often to carry that.
	property var images: []

	readonly property string imageDir: Quickshell.cachePath("clipboard-images")

	readonly property int limit: Config.clipboardLimit

	// ---- the Win+V style panel ----

	property bool shown: false
	property string query: ""
	property int index: 0

	// Kept regardless of the history cap: [{ kind, text | path, at }]. A
	// pinned entry lives here rather than being a flag on the history, so it
	// survives the two hundredth thing you copy after it.
	property var pinned: []

	// One list for the panel: pinned first, then images, then text.
	//
	// Images drop out as soon as anything is typed — they carry no text to
	// match, and leaving them at the top of a filtered list would push the
	// thing actually being searched for off the bottom.
	readonly property var rows: {
		const needle = root.query.trim().toLowerCase();
		const out = [];
		const seen = ({});

		for (const entry of root.pinned) {
			if (entry.kind === "image") {
				if (needle) continue;
				seen["i:" + entry.path] = true;
				out.push({ kind: "image", path: entry.path, at: entry.at,
					pinned: true, group: "Pinned" });
			} else {
				if (needle && entry.text.toLowerCase().indexOf(needle) === -1) continue;
				seen["t:" + entry.text] = true;
				out.push({ kind: "text", text: entry.text,
					pinned: true, group: "Pinned" });
			}
		}

		if (!needle) {
			for (const image of root.images) {
				if (seen["i:" + image.path]) continue;
				out.push({ kind: "image", path: image.path, at: image.at,
					pinned: false, group: "Recent" });
			}
		}

		for (const text of root.entries) {
			if (seen["t:" + text]) continue;
			if (needle && text.toLowerCase().indexOf(needle) === -1) continue;
			out.push({ kind: "text", text: text, pinned: false, group: "Recent" });
		}

		return out;
	}

	// Pinned entries are deliberately exempt. Pinning is how you say "not this
	// one", and a clear that ignored it would make the pin worthless.
	function clearHistory() {
		const keep = root.pinned
			.filter(e => e.kind === "image")
			.map(e => e.path);

		root.entries = [];
		store.setText("[]");

		for (const image of root.images.slice()) {
			if (keep.indexOf(image.path) !== -1) continue;
			root.removeImage(image.path);
		}
	}

	function togglePin(row) {
		if (!row) return;

		const key = row.kind === "image" ? row.path : row.text;
		const match = e => (e.kind === "image" ? e.path : e.text) === key;

		if (root.pinned.some(match)) root.pinned = root.pinned.filter(e => !match(e));
		else root.pinned = [row.kind === "image"
			? ({ kind: "image", path: row.path, at: row.at })
			: ({ kind: "text", text: row.text })].concat(root.pinned);

		pinStore.setText(JSON.stringify(root.pinned));
	}

	readonly property var selected: root.rows[root.index] ?? null

	function show() {
		root.query = "";
		root.index = 0;
		root.shown = true;
	}

	function hide() {
		root.shown = false;
		root.query = "";
		root.index = 0;
	}

	function toggle() {
		if (root.shown) root.hide();
		else root.show();
	}

	function move(delta: int) {
		const count = root.rows.length;
		if (count === 0) return;
		root.index = (root.index + delta + count) % count;
	}

	// Copying is all this can do: pressing the paste for you would mean
	// synthesising keystrokes into whatever has focus, which is both fragile
	// and not something a clipboard should take upon itself.
	function activate() {
		const row = root.selected;
		if (!row) return;

		if (row.kind === "image") root.copyImage(row.path);
		else root.copy(row.text);

		root.hide();
	}

	function removeSelected() {
		const row = root.selected;
		if (!row) return;

		// A pinned entry has to lose the pin too, or it comes straight back.
		if (row.pinned) root.togglePin(row);

		if (row.kind === "image") root.removeImage(row.path);
		else root.remove(row.text);

		const count = root.rows.length;
		if (root.index >= count) root.index = Math.max(0, count - 1);
	}

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

	function addImage(path: string) {
		if (!Config.clipboardImages) return;
		if (!path || !path.trim()) return;

		root.images = [({ path: path.trim(), at: Date.now() })]
			.concat(root.images.filter(i => i.path !== path.trim()))
			.slice(0, Config.clipboardImageLimit);

		imageStore.setText(JSON.stringify(root.images));

		if (Config.screenshotPreview) root.announceImage(path.trim());

		// Whatever fell off the end is now unreferenced.
		prune.command = ["sh", "-c",
			'cd "$1" 2>/dev/null || exit 0; '
			+ 'ls -1t *.png 2>/dev/null | tail -n +$(( $2 + 1 )) | xargs -r rm -f --',
			"sh", root.imageDir, String(Config.clipboardImageLimit)];
		prune.running = true;
	}

	// image-path is the hint the card reads to show a picture rather than an
	// icon, so the toast carries the screenshot itself.
	function announceImage(path: string) {
		const fresh = Date.now() - Notifs.lastScreenshotAt < 5000;
		Quickshell.execDetached({
			command: ["notify-send",
				"-a", fresh ? "Screenshot" : "Clipboard",
				"-h", "string:image-path:" + path,
				fresh ? "Screenshot captured" : "Image copied",
				"On the clipboard · Super+V for history"]
		});
	}

	function copyImage(path: string) {
		Quickshell.execDetached({
			command: ["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", path]
		});
	}

	function removeImage(path: string) {
		root.images = root.images.filter(i => i.path !== path);
		imageStore.setText(JSON.stringify(root.images));
		Quickshell.execDetached({ command: ["rm", "-f", "--", path] });
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

	// Images come through a script because wl-paste hands the data to a
	// command on stdin, and the command has to name a file to put it in.
	Process {
		id: imageWatcher

		running: Config.clipboardHistory && Config.clipboardImages
		command: ["wl-paste", "--type", "image/png", "--watch",
			Quickshell.shellPath("scripts/clip-image.sh"), root.imageDir]

		stdout: SplitParser {
			onRead: data => root.addImage(data)
		}
	}

	Process {
		id: prune
	}

	FileView {
		id: pinStore

		path: Quickshell.statePath("clipboard-pins")
		blockLoading: true
		printErrors: false
	}

	FileView {
		id: imageStore

		path: Quickshell.statePath("clipboard-images")
		blockLoading: true
		printErrors: false
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

		try {
			const savedImages = JSON.parse(imageStore.text().trim() || "[]");
			if (Array.isArray(savedImages)) root.images = savedImages;
		} catch (err) {
			root.images = [];
		}

		try {
			const savedPins = JSON.parse(pinStore.text().trim() || "[]");
			if (Array.isArray(savedPins)) root.pinned = savedPins;
		} catch (err) {
			root.pinned = [];
		}
	}

	IpcHandler {
		target: "clipboard"

		function toggle(): void { root.toggle(); }
		function open(): void { root.show(); }
		function close(): void { root.hide(); }

		function count(): string {
			return root.entries.length + " text, " + root.images.length + " images";
		}
	}
}
