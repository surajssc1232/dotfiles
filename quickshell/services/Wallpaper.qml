pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs

// Which image the desktop is showing.
//
// The shell paints it itself (see WallpaperLayer), so this only has to
// remember the choice — there is no external wallpaper process to drive.
Singleton {
	id: root

	readonly property string directory: Config.wallpaperDir

	// Absolute path of the wallpaper on screen.
	property string current: ""

	// Absolute path of the lock screen's picture. Empty means "whatever the
	// desktop is showing", which is the sane default: a lock screen that looks
	// like the desktop it came from does not feel like a different machine.
	property string lock: ""

	readonly property string lockEffective: root.lock || root.current

	readonly property alias model: folder
	readonly property int count: folder.count

	FolderListModel {
		id: folder

		folder: "file://" + root.directory
		nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
		showDirs: false
		showHidden: false
		// Newest first: a wallpaper just downloaded is the one being looked for.
		sortField: FolderListModel.Time
		sortReversed: false
	}

	function pathAt(index: int): string {
		return folder.get(index, "filePath") ?? "";
	}

	function nameAt(index: int): string {
		return folder.get(index, "fileName") ?? "";
	}

	function set(path: string) {
		if (!path || path === root.current) return;
		root.current = path;
		stateFile.setText(path);
	}

	function setLock(path: string) {
		if (!path || path === root.lock) return;
		root.lock = path;
		lockFile.setText(path);
	}

	// Back to following the desktop.
	function clearLock() {
		if (!root.lock) return;
		root.lock = "";
		lockFile.setText("");
	}

	FileView {
		id: stateFile

		path: Quickshell.statePath("wallpaper")
		blockLoading: true
		printErrors: false
	}

	FileView {
		id: lockFile

		path: Quickshell.statePath("lock-wallpaper")
		blockLoading: true
		printErrors: false
	}

	// ---- taking over from an external wallpaper setter ----
	//
	// On a machine that was using swaybg, its picture is adopted so the desktop
	// looks unchanged, and the process is then stopped: it draws on the same
	// layer as this shell does, and two of them fighting over the background is
	// not something to leave to chance.
	Process {
		id: adopt

		// Anchored to a path boundary so it matches the program being run and
		// not any shell whose arguments merely mention it. Matching the
		// process name instead is not an option: Nix runs it as
		// .swaybg-wrapped, and pgrep cannot exact-match a name that long.
		readonly property string pattern: "(^|/)[.]?swaybg[^ ]* -i "

		command: ["sh", "-c",
			"pgrep -af '" + pattern + "' | head -n1 "
			+ "| sed -n 's/.*-i \\([^ ]*\\).*/\\1/p'"]

		stdout: StdioCollector {
			onStreamFinished: {
				const running = text.trim();
				if (!root.current && running) root.current = running;
				if (running) {
					stopper.command = ["pkill", "-f", adopt.pattern];
					stopper.running = true;
				}
			}
		}
	}

	Process { id: stopper }

	Component.onCompleted: {
		const saved = stateFile.text().trim();
		if (saved) root.current = saved;

		const savedLock = lockFile.text().trim();
		if (savedLock) root.lock = savedLock;
		adopt.running = true;
	}
}
