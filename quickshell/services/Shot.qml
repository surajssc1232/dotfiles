pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Screenshots, captured through wlr-screencopy inside the shell itself —
// no grim, no external capture tool.
Singleton {
	id: root

	// "region" waits for a drag; "full" takes the whole output at once.
	property string mode: "region"
	// Overlays watch this to arm themselves.
	property bool capturing: false
	// Set once the frame is safely in hand. Anything that deliberately stayed
	// on screen to be photographed can take itself down at this point: the
	// pixels are already captured, and leaving two overlay surfaces up during
	// a region drag means they compete for the pointer.
	property bool frameReady: false
	property string lastPath: ""

	readonly property string directory: Quickshell.env("HOME") + "/Pictures/Screenshots"

	signal saved(string path)
	signal failed(string reason)

	function fileName(): string {
		const d = new Date();
		const p = n => (n < 10 ? "0" : "") + n;
		return "Screenshot_" + d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
			+ "_" + p(d.getHours()) + "-" + p(d.getMinutes()) + "-" + p(d.getSeconds()) + ".png";
	}

	function nextPath(): string {
		return root.directory + "/" + root.fileName();
	}

	// `delayMs` lets whatever asked for the shot get itself off screen first:
	// the control centre is a layer surface like any other and would otherwise
	// be composited into the capture.
	function start(mode: string, delayMs: int) {
		// Disabled in one place rather than by unbinding keys: the keybind
		// scripts, the launcher and the IPC handler all arrive here.
		if (!Config.screenshot) return;

		if (root.capturing) return;
		root.mode = mode;
		arm.interval = Math.max(1, delayMs);
		arm.restart();
	}

	function cancel() {
		root.capturing = false;
		root.frameReady = false;
	}

	Timer {
		id: arm
		onTriggered: root.capturing = true
	}

	// The capture surface takes the keyboard exclusively and covers the
	// screen. If a frame never arrives, or a selection is simply abandoned,
	// this makes sure it cannot sit there indefinitely.
	Timer {
		interval: 60000
		running: root.capturing
		onTriggered: {
			root.capturing = false;
			root.frameReady = false;
			root.failed("Timed out");
		}
	}

	// Called by the overlay once a grab has been written to disk.
	function afterSave(path: string, ok: bool) {
		root.capturing = false;
		root.frameReady = false;
		if (!ok) {
			root.failed("Could not write " + path);
			notify.command = ["notify-send", "-a", "Screenshot", "-u", "critical",
				"Screenshot failed", "Could not write to " + root.directory];
			notify.running = true;
			return;
		}

		root.lastPath = path;
		root.saved(path);

		// Straight to the clipboard, which is what a screenshot is usually for.
		clip.command = ["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", path];
		clip.running = true;

		// The saved file doubles as the notification's own thumbnail.
		notify.command = ["notify-send", "-a", "Screenshot", "-i", path,
			"Screenshot saved", path.split("/").pop() + " — copied to clipboard"];
		notify.running = true;
	}

	// Triggered by the compositor's keybinds, which know nothing about this
	// shell beyond a command to run — so the binding stays compositor
	// independent:
	//
	//   qs ipc call screenshot region
	//   qs ipc call screenshot full
	//   qs ipc call screenshot delayed 3
	IpcHandler {
		target: "screenshot"

		function region(): void {
			root.start("region", 1);
		}

		function full(): void {
			root.start("full", 1);
		}

		function delayed(seconds: int): void {
			root.start("full", Math.max(1, seconds) * 1000);
		}

		function cancel(): void {
			root.cancel();
		}
	}

	Process { id: clip }
	Process { id: notify }
	Process { id: mkdir }

	// The directory has to exist before a grab callback tries to write into
	// it: saveToFile is synchronous and will not create the path itself.
	Component.onCompleted: {
		mkdir.command = ["mkdir", "-p", root.directory];
		mkdir.running = true;
	}
}
