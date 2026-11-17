pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Storage review: what in $HOME is junk that can go, what is big, and where
// the space is. Scanning is done by scripts/storage-scan.py, which only
// measures; everything destructive happens here, and only ever on a path
// inside $HOME.
//
// Opening is instant: the last scan is kept on disk and shown straight away,
// and a fresh scan only starts when that one is old. While a scan runs over
// an existing result the old rows stay up and are swapped out at the end;
// with nothing to show yet, rows appear as they are found.
Singleton {
	id: root

	property bool shown: false

	// Where the bar's pill sits on each screen, by screen name, so the panel
	// can open underneath it. The pills publish this as the panel opens.
	property var pillCentres: ({})

	function setPillCentre(screen: string, x: real) {
		if (root.pillCentres[screen] === x) return;
		const next = Object.assign({}, root.pillCentres);
		next[screen] = x;
		root.pillCentres = next;
	}

	property bool scanning: false
	// Scan progress: directories measured out of those queued, and the last.
	property int progressDone: 0
	property int progressTotal: 0
	property string progressName: ""
	readonly property real progress: root.progressTotal > 0
		? root.progressDone / root.progressTotal : 0

	// When the rows on show were measured, in seconds; 0 before any scan.
	property real scannedAt: 0
	// A cached result older than this is re-measured on open.
	readonly property int staleSeconds: 600

	// Bytes removed since the shell started, for the footer.
	property real freed: 0

	// [{ kind, bytes, mtime (seconds), path, name, parent }]
	property var items: []

	// "overview" | "junk" | "large" | "folders"
	property string tab: "overview"
	// "size" | "name" | "age"
	property string sortKey: "size"
	property bool descending: true
	// One junk kind to narrow the junk tab to, or "" for all of them.
	property string junkFilter: ""
	// Narrows every list to names or paths containing it.
	property string filter: ""
	// The folder the folders tab is looking into.
	property string folder: root.home

	// Root filesystem, for the header meter.
	property real diskTotal: 0
	property real diskUsed: 0
	property int diskPercent: 0

	readonly property string home: Quickshell.env("HOME")
	readonly property string cacheFile: Quickshell.statePath("storage-scan.tsv")

	readonly property var junkKinds: ["trash", "cache", "dev", "junk", "broken", "build"]
	readonly property var kindNames: ({
		trash: "Trash", cache: "App cache", dev: "Package cache", junk: "Junk file",
		broken: "Broken link", build: "Build output", large: "Large file",
		folder: "Folder", dir: "Folder", other: "Files"
	})

	function isJunk(item): bool { return root.junkKinds.indexOf(item.kind) !== -1; }

	// Folders by the folder that holds them, for drilling in without a rescan.
	readonly property var childMap: {
		const map = ({});
		for (const i of root.items) {
			if (i.kind !== "folder" && i.kind !== "dir" && i.kind !== "large") continue;
			if (!map[i.parent]) map[i.parent] = [];
			map[i.parent].push(i);
		}
		return map;
	}

	// The folder on show in the folders tab, as an item, for its total.
	readonly property var folderItem: root.items.find(i =>
		(i.kind === "folder" || i.kind === "dir") && i.path === root.folder) ?? null

	readonly property var folderRows: {
		const list = (root.childMap[root.folder] ?? []).slice();
		// What the listed folders and files leave over: small sub-folders and
		// files not worth a row each. Never shown for $HOME itself, where loose
		// files are rarely the story and the total would only be a guess.
		if (root.folderItem) {
			const listed = list.reduce((sum, i) => sum + i.bytes, 0);
			const rest = root.folderItem.bytes - listed;
			if (rest > 1024 * 1024) list.push({
				kind: "other", bytes: rest, mtime: root.folderItem.mtime,
				path: root.folder, name: "Smaller files and folders", parent: root.folder
			});
		}
		return list;
	}

	// The breadcrumb over the folders tab: [{ name, path }], $HOME first.
	readonly property var crumbs: {
		const out = [{ name: "~", path: root.home }];
		if (root.folder === root.home) return out;
		const parts = root.folder.slice(root.home.length + 1).split("/");
		let p = root.home;
		for (const part of parts) {
			p += "/" + part;
			out.push({ name: part, path: p });
		}
		return out;
	}

	function hasChildren(path: string): bool {
		return (root.childMap[path] ?? []).some(i => i.kind !== "large");
	}

	function openFolder(path: string) {
		root.folder = path;
		root.tab = "folders";
	}

	readonly property var rows: {
		let list;
		if (root.tab === "folders") list = root.folderRows;
		else if (root.tab === "large") list = root.items.filter(i => i.kind === "large");
		else list = root.items.filter(i => root.junkFilter
			? i.kind === root.junkFilter : root.isJunk(i));

		const f = root.filter.trim().toLowerCase();
		if (f) list = list.filter(i => i.path.toLowerCase().indexOf(f) !== -1);

		const dir = root.descending ? -1 : 1;
		// Ascending is smallest, oldest, A first; descending flips it. The
		// leftover row of a folder always sinks to the bottom.
		return list.slice().sort((a, b) => {
			if (a.kind === "other" || b.kind === "other") return a.kind === "other" ? 1 : -1;
			const r = root.sortKey === "name" ? a.name.localeCompare(b.name)
				: root.sortKey === "age" ? a.mtime - b.mtime
				: a.bytes - b.bytes;
			return r * dir || a.name.localeCompare(b.name);
		});
	}

	readonly property var junkItems: root.items.filter(i => root.isJunk(i))
	readonly property real junkBytes: root.junkItems.reduce((sum, i) => sum + i.bytes, 0)
	readonly property int junkCount: root.junkItems.length

	// What "clean all" would take on the junk tab, with its filters applied.
	readonly property var cleanable: root.tab === "junk" ? root.rows : root.junkItems
	readonly property real cleanableBytes: root.cleanable.reduce((sum, i) => sum + i.bytes, 0)

	// Junk grouped by kind, biggest first: [{ kind, bytes, count }]
	readonly property var kindTotals: {
		const sums = ({});
		for (const i of root.junkItems) {
			if (!sums[i.kind]) sums[i.kind] = { kind: i.kind, bytes: 0, count: 0 };
			const s = sums[i.kind];
			s.bytes += i.bytes;
			s.count++;
		}
		return Object.values(sums).sort((a, b) => b.bytes - a.bytes);
	}

	// The eight biggest folders in $HOME.
	readonly property var topFolders: root.items.filter(i => i.kind === "folder")
		.sort((a, b) => b.bytes - a.bytes).slice(0, 8)

	readonly property real largeBytes: root.items.filter(i => i.kind === "large")
		.reduce((sum, i) => sum + i.bytes, 0)

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

	function ago(seconds: real): string {
		const s = Math.max(0, Date.now() / 1000 - seconds);
		if (s < 60) return "just now";
		if (s < 3600) return Math.floor(s / 60) + " min ago";
		if (s < 86400) return Math.floor(s / 3600) + " h ago";
		return Math.floor(s / 86400) + " d ago";
	}

	function show() {
		root.shown = true;
		diskProbe.running = true;
		if (root.items.length === 0) root.loadCache();
		if (Date.now() / 1000 - root.scannedAt > root.staleSeconds) root.scan();
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

	function setTab(key: string) {
		root.tab = key;
		root.filter = "";
	}

	// ---- scanning ----

	// Rows found by the scan under way, not yet on show.
	property var pending: []
	// Paths removed while a scan was running, kept out of its result.
	property var gone: ({})
	// Whether the scan in flight fills the list as it goes (nothing to show
	// before it) or replaces the list once it is done.
	property bool streaming: false

	function scan() {
		if (scanner.running) return;
		root.pending = [];
		root.gone = ({});
		root.progressDone = 0;
		root.progressTotal = 0;
		root.progressName = "";
		root.streaming = root.items.length === 0;
		root.scanning = true;
		scanner.running = true;
		diskProbe.running = true;
	}

	function parentOf(path: string): string {
		return path.slice(0, path.lastIndexOf("/"));
	}

	function parseLine(line: string, into) {
		const p = line.split("\t");
		if (p.length < 4) return;
		const path = p.slice(3).join("\t");
		if (p[0] === "progress") {
			root.progressDone = Number(p[1]) || 0;
			root.progressTotal = Number(p[2]) || 0;
			root.progressName = path;
			return;
		}
		if (p[0] === "scanned") {
			root.scannedAt = Number(p[2]) || 0;
			return;
		}
		into.push({
			kind: p[0],
			bytes: Number(p[1]) || 0,
			mtime: Math.floor(Number(p[2])) || 0,
			path: path,
			name: path.split("/").pop(),
			parent: root.parentOf(path)
		});
	}

	function loadCache() {
		cache.reload();
		const text = cache.text();
		if (!text) return;
		const out = [];
		for (const line of text.split("\n")) root.parseLine(line, out);
		root.items = out;
	}

	// Streams found rows onto the screen a few times a second, rather than
	// rebuilding every list on every one of hundreds of lines.
	Timer {
		interval: 250
		repeat: true
		running: root.scanning && root.streaming
		onTriggered: root.items = root.pending.filter(i => !root.gone[i.path])
	}

	Process {
		id: scanner

		// Low priority, but best-effort rather than idle IO: the idle class
		// stalls behind any other disk activity at all, which is what made
		// a scan take minutes whenever something was downloading.
		command: ["nice", "-n", "19", "ionice", "-c2", "-n7",
			"python3", Quickshell.shellPath("scripts/storage-scan.py"), root.cacheFile]

		stdout: SplitParser {
			onRead: line => root.parseLine(line, root.pending)
		}

		onExited: {
			root.items = root.pending.filter(i => !root.gone[i.path]);
			root.pending = [];
			root.scannedAt = Date.now() / 1000;
			root.scanning = false;
			// Drilled into something that is gone or now too small to list.
			if (root.folder !== root.home && !root.folderItem) root.folder = root.home;
		}
	}

	FileView {
		id: cache

		path: root.cacheFile
		blockLoading: true
		printErrors: false
		watchChanges: false
	}

	Process {
		id: diskProbe

		command: ["df", "-B1", "--output=size,used,pcent", root.home]

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

	// Takes removed items off the list, and their size off every folder that
	// held them, so the totals stay right without a rescan.
	function drop(removed) {
		const paths = ({});
		let bytes = 0;
		for (const r of removed) { paths[r.path] = true; bytes += r.bytes; }

		const g = Object.assign({}, root.gone);
		for (const p in paths) g[p] = true;
		root.gone = g;

		root.items = root.items
			.filter(i => !paths[i.path] && !removed.some(r => i.path.indexOf(r.path + "/") === 0))
			.map(i => {
				if (i.kind !== "folder" && i.kind !== "dir") return i;
				let less = 0;
				for (const r of removed) if (r.path.indexOf(i.path + "/") === 0) less += r.bytes;
				return less > 0 ? Object.assign({}, i, { bytes: Math.max(0, i.bytes - less) }) : i;
			});
		return bytes;
	}

	function remove(item) {
		if (!root.safe(item.path)) return;
		root.queue = root.queue.concat([{ item: item, how: "delete" }]);
		root.freed += root.drop([item]);
		root.next();
	}

	// Into the trash rather than gone: for large files, which are seldom junk
	// and sometimes regretted. Frees nothing until the trash is emptied, so
	// the trash row grows by what went into it.
	function trash(item) {
		if (!root.safe(item.path)) return;
		root.queue = root.queue.concat([{ item: item, how: "trash" }]);
		root.drop([item]);
		const t = root.items.find(i => i.kind === "trash");
		if (t) root.items = root.items.map(i => i === t
			? Object.assign({}, t, { bytes: t.bytes + item.bytes }) : i);
		root.next();
	}

	// Everything junk in the current list: all of it, or what the junk tab's
	// kind and text filters have narrowed it to.
	function cleanAll() {
		const list = root.cleanable.filter(i => root.isJunk(i) && root.safe(i.path));
		root.queue = root.queue.concat(list.map(i => ({ item: i, how: "delete" })));
		root.freed += root.drop(list);
		root.junkFilter = "";
		root.next();
	}

	function next() {
		if (remover.running || root.queue.length === 0) return;
		const job = root.queue[0];
		const item = job.item;
		root.queue = root.queue.slice(1);

		if (job.how === "trash") {
			// The freedesktop layout, as FileSearch writes it, so the file
			// manager's Restore still knows where it came from.
			remover.command = ["sh", "-c",
				't="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"; mkdir -p "$t/files" "$t/info" && '
				+ 'n=$(basename "$1"); d="$n"; i=1; '
				+ 'while [ -e "$t/files/$d" ] || [ -e "$t/info/$d.trashinfo" ]; do d="$n.$i"; i=$((i+1)); done; '
				+ 'printf "[Trash Info]\\nPath=%s\\nDeletionDate=%s\\n" "$(realpath -- "$1")" "$(date +%Y-%m-%dT%H:%M:%S)" > "$t/info/$d.trashinfo" && '
				+ 'mv -- "$1" "$t/files/$d"', "sh", item.path];
		} else if (item.kind === "trash") {
			// The trash is emptied, not deleted, so the folder survives.
			remover.command = ["sh", "-c",
				"find \"$1/files\" \"$1/info\" \"$1/expunged\" -mindepth 1 -delete 2>/dev/null; true",
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
		function rescan(): void { root.scan(); }
	}
}
