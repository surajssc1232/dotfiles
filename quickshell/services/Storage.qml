pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Storage review: what in $HOME is junk that can go, what is big, and where
// the space is. Scanning is done by scripts/storage-scan.sh, which only
// measures; everything destructive happens here, and only ever on a path
// inside $HOME.
Singleton {
	id: root

	property bool shown: false
	property bool scanning: false

	// [{ kind, bytes, mtime (seconds), path, name }]
	property var items: []

	// "overview" | "junk" | "large" | "folders"
	property string tab: "overview"
	// "size" | "name" | "age"
	property string sortKey: "size"
	property bool descending: true

	// Root filesystem, for the header meter.
	property real diskTotal: 0
	property real diskUsed: 0
	property int diskPercent: 0

	readonly property string home: Quickshell.env("HOME")

	readonly property var junkKinds: ["trash", "cache", "dev", "junk", "broken", "build"]
	readonly property var kindNames: ({
		trash: "Trash", cache: "App cache", dev: "Package cache", junk: "Junk file",
		broken: "Broken link", build: "Build output", large: "Large file", folder: "Folder"
	})

	readonly property var rows: {
		const kinds = root.tab === "junk" ? root.junkKinds
			: root.tab === "large" ? ["large"] : ["folder"];
		const list = root.items.filter(i => kinds.indexOf(i.kind) !== -1);
		const dir = root.descending ? -1 : 1;
		// Ascending is smallest, oldest, A first; descending flips it.
		list.sort((a, b) => {
			const r = root.sortKey === "name" ? a.name.localeCompare(b.name)
				: root.sortKey === "age" ? a.mtime - b.mtime
				: a.bytes - b.bytes;
			return r * dir || a.name.localeCompare(b.name);
		});
		return list;
	}

	readonly property real junkBytes: root.items
		.filter(i => root.junkKinds.indexOf(i.kind) !== -1)
		.reduce((sum, i) => sum + i.bytes, 0)

	// Junk grouped by kind, biggest first: [{ kind, bytes }]
	readonly property var kindTotals: {
		const sums = ({});
		for (const i of root.items) {
			if (root.junkKinds.indexOf(i.kind) !== -1) sums[i.kind] = (sums[i.kind] ?? 0) + i.bytes;
		}
		return Object.keys(sums).map(k => ({ kind: k, bytes: sums[k] }))
			.sort((a, b) => b.bytes - a.bytes);
	}

	// The eight biggest folders in $HOME.
	readonly property var topFolders: root.items.filter(i => i.kind === "folder")
		.sort((a, b) => b.bytes - a.bytes).slice(0, 8)

	readonly property int junkCount: root.items
		.filter(i => root.junkKinds.indexOf(i.kind) !== -1).length

	function size(bytes: real): string {
		const units = ["B", "KB", "MB", "GB", "TB"];
		let v = bytes;
		let u = 0;
		while (v >= 1024 && u < units.length - 1) { v /= 1024; u++; }
		return (u === 0 ? Math.round(v) : v.toFixed(v >= 100 ? 0 : 1)) + " " + units[u];
	}

	function age(mtime: real): string {
		const days = Math.floor((Date.now() / 1000 - mtime) / 86400);
		if (days < 1) return "today";
		if (days < 31) return days + "d ago";
		if (days < 365) return Math.floor(days / 30) + "mo ago";
		return Math.floor(days / 365) + "y ago";
	}

	function show() {
		root.shown = true;
		root.scan();
	}

	function hide() { root.shown = false; }

	function toggle() {
		if (root.shown) root.hide();
		else root.show();
	}

	function setSort(key: string) {
		if (root.sortKey === key) root.descending = !root.descending;
		else { root.sortKey = key; root.descending = key !== "name"; }
	}

	function scan() {
		if (scanner.running) return;
		root.items = [];
		root.scanning = true;
		pending = [];
		scanner.running = true;
		diskProbe.running = true;
	}

	property var pending: []

	function parseLine(line: string) {
		const p = line.split("\t");
		if (p.length < 4) return;
		const path = p.slice(3).join("\t");
		pending.push({
			kind: p[0],
			bytes: Number(p[1]) || 0,
			mtime: Math.floor(Number(p[2])) || 0,
			path: path,
			name: path.split("/").pop()
		});
	}

	Process {
		id: scanner

		command: ["nice", "-n", "19", "ionice", "-c3",
			Quickshell.shellPath("scripts/storage-scan.sh")]

		stdout: SplitParser {
			onRead: line => root.parseLine(line)
		}

		onExited: {
			root.items = root.pending;
			root.scanning = false;
		}
	}

	Process {
		id: diskProbe

		command: ["df", "-B1", "--output=size,used,pcent", "/"]

		stdout: StdioCollector {
			onStreamFinished: {
				const l = this.text.trim().split("\n")[1];
				if (!l) return;
				const c = l.trim().split(/\s+/);
				root.diskTotal = Number(c[0]);
				root.diskUsed = Number(c[1]);
				root.diskPercent = parseInt(c[2]);
			}
		}
	}

	// ---- removal ----

	// Only paths strictly inside $HOME, with no way to climb out.
	function safe(path: string): bool {
		return path.indexOf(root.home + "/") === 0 && path.indexOf("..") === -1
			&& path.length > root.home.length + 2;
	}

	property var queue: []

	function remove(item) {
		if (!root.safe(item.path)) return;
		root.queue = root.queue.concat([item]);
		root.items = root.items.filter(i => i.path !== item.path);
		root.next();
	}

	// Everything in the current list that counts as junk.
	function cleanAll() {
		const gone = root.items.filter(i => root.junkKinds.indexOf(i.kind) !== -1);
		for (const item of gone) root.queue = root.queue.concat([item]);
		root.items = root.items.filter(i => root.junkKinds.indexOf(i.kind) === -1);
		root.next();
	}

	function next() {
		if (remover.running || root.queue.length === 0) return;
		const item = root.queue[0];
		root.queue = root.queue.slice(1);

		// The trash is emptied, not deleted, so the folder survives.
		if (item.kind === "trash") {
			remover.command = ["sh", "-c",
				"find \"$1/files\" \"$1/info\" -mindepth 1 -delete 2>/dev/null; true",
				"sh", item.path];
		} else {
			remover.command = ["rm", "-rf", "--one-file-system", "--", item.path];
		}
		remover.running = true;
	}

	Process {
		id: remover

		onExited: {
			diskProbe.running = true;
			root.next();
		}
	}

	IpcHandler {
		target: "storage"

		function toggle(): void { root.toggle(); }
		function open(): void { root.show(); }
		function close(): void { root.hide(); }
	}
}
