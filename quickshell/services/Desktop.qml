pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Icons on the desktop, the way Windows does it: applications put there from
// the launcher (right-click → Add to desktop, or Ctrl+D), plus whatever is in
// ~/Desktop. Double-click opens, drag rearranges, right-click for a menu.
//
// This holds what is on the desktop and where; modules/DesktopIcons.qml draws
// it on the wallpaper layer and modules/DesktopMenu.qml is its context menu.
Singleton {
	id: root

	// Icons at all, and whether ~/Desktop's own files are among them.
	property bool enabled: true
	property bool showFiles: true

	// Desktop entry ids, in the order they were added.
	property var apps: []

	// Grid cell per icon key, { key: { c, r } }. Icons without one take the
	// first free cell, top to bottom and then left to right.
	property var positions: ({})

	readonly property string folder: Quickshell.env("HOME") + "/Desktop"

	// Selected icons, as a set of keys: { key: true }. A click selects one,
	// Ctrl+click adds or takes away, a drag across the desktop selects what
	// the box touches.
	property var selection: ({})
	readonly property var selectedKeys: Object.keys(root.selection)
	readonly property var selectedItems: root.items.filter(i => root.selection[i.key])

	function isSelected(key: string): bool { return root.selection[key] === true; }

	function select(keys) {
		const next = ({});
		for (const k of keys) next[k] = true;
		root.selection = next;
	}

	function toggleSelected(key: string) {
		const next = Object.assign({}, root.selection);
		if (next[key]) delete next[key];
		else next[key] = true;
		root.selection = next;
	}

	function clearSelection() {
		if (root.selectedKeys.length > 0) root.selection = ({});
	}

	function setEnabled(on: bool) {
		root.enabled = on;
		Persist.set("desktopIcons", on);
	}

	function toggle() { root.setEnabled(!root.enabled); }

	function setShowFiles(on: bool) {
		root.showFiles = on;
		Persist.set("desktopFiles", on);
	}

	// ---- applications ----

	function has(id: string): bool { return root.apps.indexOf(id) !== -1; }

	function add(id: string) {
		if (!id || root.has(id)) return;
		root.apps = root.apps.concat([id]);
		Persist.set("desktopApps", root.apps);
		// Turning icons back on is the obvious expectation after adding one.
		if (!root.enabled) root.setEnabled(true);
	}

	function remove(id: string) {
		root.apps = root.apps.filter(a => a !== id);
		Persist.set("desktopApps", root.apps);
		root.forget("app:" + id);
	}

	function toggleApp(id: string) {
		if (root.has(id)) root.remove(id);
		else root.add(id);
	}

	// ---- placement ----

	function forget(key: string) {
		if (!(key in root.positions)) return;
		const next = Object.assign({}, root.positions);
		delete next[key];
		root.setPositions(next);
	}

	function setPositions(map) {
		root.positions = map;
		Persist.set("desktopPositions", map);
	}

	// Drops `key` on a cell. Whatever was there takes the dragged icon's old
	// cell. Every icon's current cell is written down at the same time, so
	// none of the auto-placed ones shuffle along when this one moves.
	function move(key: string, c: int, r: int, cells) {
		const next = Object.assign({}, root.positions);
		for (const k in cells) next[k] = { c: cells[k].c, r: cells[k].r };
		const from = next[key];
		if (!from || (from.c === c && from.r === r)) return;
		for (const k in cells) {
			if (k !== key && next[k].c === c && next[k].r === r) {
				next[k] = { c: from.c, r: from.r };
				break;
			}
		}
		next[key] = { c: c, r: r };
		root.setPositions(next);
	}

	// Several icons dragged together by one offset, in cells. A drop that
	// would push any of them off the grid or onto the graphs is refused.
	// Icons that were in the way move into the cells the dragged ones left,
	// or failing that the first free cell, so nothing ends up stacked.
	function moveMany(keys, dc: int, dr: int, cells, cols: int, rows: int, blocked) {
		if (dc === 0 && dr === 0) return;
		const moving = ({});
		for (const k of keys) if (cells[k]) moving[k] = true;

		const next = ({});
		for (const k in cells) next[k] = { c: cells[k].c, r: cells[k].r };

		const targets = ({});
		for (const k in moving) {
			const c = next[k].c + dc, r = next[k].r + dr;
			if (c < 0 || r < 0 || c >= cols || r >= rows || blocked(c, r)) return;
			targets[c + "," + r] = true;
		}

		const vacated = [];
		for (const k in moving) {
			const from = next[k];
			if (!targets[from.c + "," + from.r]) vacated.push({ c: from.c, r: from.r });
			next[k] = { c: from.c + dc, r: from.r + dr };
		}

		const taken = ({});
		for (const k in next) if (!moving[k]) taken[next[k].c + "," + next[k].r] = k;
		for (const t in targets) taken[t] = true;

		for (const k in cells) {
			if (moving[k] || !targets[cells[k].c + "," + cells[k].r]) continue;
			let spot = vacated.shift();
			if (!spot) {
				for (let n = 0; n < cols * rows && !spot; n++) {
					const c = Math.floor(n / rows), r = n % rows;
					if (!taken[c + "," + r] && !blocked(c, r)) spot = { c: c, r: r };
				}
			}
			if (!spot) return;
			next[k] = spot;
			taken[spot.c + "," + spot.r] = true;
		}

		root.setPositions(Object.assign({}, root.positions, next));
	}

	// ---- auto arrange ----
	// As on Windows: icons stay packed down the left edge in order, filling
	// any gap the moment one opens up, and dragging one reorders the run
	// instead of leaving a hole. `order` is that run, by key; icons not in it
	// yet follow on in the order of `items`.
	property bool autoArrange: true
	property var order: []

	function setAutoArrange(on: bool) {
		root.autoArrange = on;
		Persist.set("desktopAutoArrange", on);
	}

	function ordered(): var {
		const rank = ({});
		root.order.forEach((k, i) => rank[k] = i);
		const known = root.items.filter(i => rank[i.key] !== undefined)
			.sort((a, b) => rank[a.key] - rank[b.key]);
		return known.concat(root.items.filter(i => rank[i.key] === undefined));
	}

	function setOrder(keys) {
		root.order = keys;
		Persist.set("desktopOrder", keys);
	}

	// Takes the dragged icons out of the run and puts them back, in their
	// own order, starting at slot `at`.
	function reorder(keys, at: int) {
		const moving = ({});
		for (const k of keys) moving[k] = true;
		const all = root.ordered().map(i => i.key);
		const picked = all.filter(k => moving[k]);
		const rest = all.filter(k => !moving[k]);
		const i = Math.max(0, Math.min(at, rest.length));
		root.setOrder(rest.slice(0, i).concat(picked, rest.slice(i)));
	}

	// Everything back into a column-first run, sorted by name: with no cells
	// remembered, the grid fills itself in the order of `items`.
	property bool sorted: false

	function sortByName() {
		root.sorted = true;
		Persist.set("desktopSorted", true);
		root.setPositions(({}));
		root.setOrder([]);
	}

	// ---- what is on it ----

	readonly property var appItems: {
		// Depending on the catalogue means an app installed after login, or
		// one that comes back after an update, appears without a restart.
		void DesktopEntries.applications.values.length;
		const out = [];
		for (const id of root.apps) {
			const e = DesktopEntries.byId(id);
			if (!e) continue;
			out.push({ key: "app:" + id, kind: "app", id: id, name: e.name,
				iconName: e.icon ?? "", entry: e, path: "", isDir: false, image: false });
		}
		return out;
	}

	property var fileItems: []

	readonly property var items: {
		const all = root.showFiles ? root.appItems.concat(root.fileItems) : root.appItems;
		return !root.sorted ? all : all.slice().sort((a, b) =>
			(b.isDir - a.isDir) || a.name.localeCompare(b.name));
	}

	readonly property var imageTypes: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"]

	function fileIcon(name: string, isDir: bool): string {
		if (isDir) return "folder";
		const ext = name.indexOf(".") > 0 ? name.split(".").pop().toLowerCase() : "";
		if (["mp4", "mkv", "webm", "mov", "avi"].indexOf(ext) !== -1) return "video-x-generic";
		if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].indexOf(ext) !== -1) return "audio-x-generic";
		if (ext === "pdf") return "application-pdf";
		if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(ext) !== -1) return "package-x-generic";
		if (["sh", "py", "js", "ts", "rs", "c", "cpp", "go", "java", "qml", "nix", "lua"].indexOf(ext) !== -1)
			return "text-x-script";
		if (["html", "htm"].indexOf(ext) !== -1) return "text-html";
		if (["doc", "docx", "odt"].indexOf(ext) !== -1) return "x-office-document";
		if (["xls", "xlsx", "ods", "csv"].indexOf(ext) !== -1) return "x-office-spreadsheet";
		if (["ppt", "pptx", "odp"].indexOf(ext) !== -1) return "x-office-presentation";
		if (root.imageTypes.indexOf(ext) !== -1) return "image-x-generic";
		return "text-x-generic";
	}

	function readFolder() {
		const out = [];
		for (let i = 0; i < files.count; i++) {
			const name = files.get(i, "fileName");
			const path = files.get(i, "filePath");
			const isDir = files.get(i, "fileIsDir");
			const ext = name.split(".").pop().toLowerCase();

			// A launcher dropped into ~/Desktop the freedesktop way opens the
			// app it names, not a text editor on the file.
			const entry = ext === "desktop" ? DesktopEntries.byId(name.slice(0, -8)) : null;

			out.push({
				key: "file:" + path, kind: entry ? "app" : "file", id: "",
				name: entry ? entry.name : name,
				iconName: entry ? (entry.icon ?? "") : root.fileIcon(name, isDir),
				entry: entry, path: path, isDir: isDir,
				image: !isDir && root.imageTypes.indexOf(ext) !== -1
			});
		}
		root.fileItems = out;
	}

	FolderListModel {
		id: files

		folder: "file://" + root.folder
		showDirsFirst: true
		showHidden: false
		showDotAndDotDot: false
		sortField: FolderListModel.Name

		// A rename keeps the count, so the row signals are watched as well.
		onStatusChanged: if (status === FolderListModel.Ready) root.readFolder()
		onCountChanged: root.readFolder()
		onRowsInserted: root.readFolder()
		onRowsRemoved: root.readFolder()
		onModelReset: root.readFolder()
		onDataChanged: root.readFolder()
	}

	// ---- acting on icons ----

	function open(item) {
		if (!item) return;
		if (item.kind === "app" && item.entry) {
			Launcher.launch(item.entry, item.entry);
			if (item.id) Launcher.remember(item.id);
		} else if (item.path) {
			FileSearch.open(item.path);
		}
	}

	function trash(item) {
		if (!item?.path) return;
		FileSearch.trash(item.path);
		root.forget(item.key);
	}

	// What a right-click menu acts on: every selected icon when the click was
	// on one of them, otherwise just the icon clicked.
	readonly property var menuTargets: !root.menuItem ? []
		: root.isSelected(root.menuItem.key) && root.selectedItems.length > 1
			? root.selectedItems : [root.menuItem]

	// ---- context menu ----
	// One menu at a time, on one screen. `menuItem` is the icon it is for, or
	// null for the desktop itself.
	property bool menuOpen: false
	property var menuItem: null
	property string menuScreen: ""
	property point menuAt: Qt.point(0, 0)
	function openMenu(item, screen: string, at: point) {
		root.menuItem = item;
		root.menuScreen = screen;
		root.menuAt = at;
		root.menuOpen = true;
	}

	function closeMenu() { root.menuOpen = false; }

	IpcHandler {
		target: "desktop"

		function toggle(): void { root.toggle(); }
		function add(id: string): void { root.add(id); }
		function remove(id: string): void { root.remove(id); }
		function sort(): void { root.sortByName(); }
		function autoArrange(on: bool): void { root.setAutoArrange(on); }
	}

	// Read once here rather than as bindings: Persist parses its file on the
	// first get(), and doing that inside a binding is a binding loop.
	Component.onCompleted: {
		root.enabled = Persist.get("desktopIcons", true);
		root.showFiles = Persist.get("desktopFiles", true);
		const apps = Persist.get("desktopApps", []);
		root.apps = Array.isArray(apps) ? apps : [];
		const pos = Persist.get("desktopPositions", ({}));
		root.positions = pos && typeof pos === "object" ? pos : ({});
		root.sorted = Persist.get("desktopSorted", false);
		root.autoArrange = Persist.get("desktopAutoArrange", true);
		const order = Persist.get("desktopOrder", []);
		root.order = Array.isArray(order) ? order : [];
	}
}
