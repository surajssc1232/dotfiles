pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// Alt-Tab window switching.
//
// The window list comes from wlr-foreign-toplevel-management, so this works on
// any wlroots compositor rather than through a compositor-specific IPC.
//
// Ordering is most-recently-used, not creation order: that is what makes a
// single Alt-Tab flip between the last two windows, which is most of what a
// switcher is ever asked to do.
Singleton {
	id: root

	property bool open: false
	property int index: 0

	// What was focused when the switcher opened, so Escape can put it back.
	property var origin: null

	// MRU order, most recent first. Rebuilt against the live toplevel list on
	// every read so a closed window can never be activated.
	property var order: []

	readonly property var windows: {
		const live = ToplevelManager.toplevels.values;
		const ranked = root.order.filter(w => live.indexOf(w) !== -1);
		// Anything never focused yet goes on the end, in the order it appeared.
		for (const w of live)
			if (ranked.indexOf(w) === -1) ranked.push(w);
		return ranked;
	}

	readonly property var selected: root.windows[root.index] ?? null

	function title(w): string {
		if (!w) return "";
		return w.title || w.appId || "Untitled";
	}

	function show() {
		// Disabled outright by config, rather than by unbinding it in the
		// compositor: this way every trigger — the keybind, the pipe, the IPC
		// call — goes quiet at once, and turning it back on is one line.
		if (!Config.switcher) return;

		const n = root.windows.length;
		if (n === 0) return;

		if (root.open) {
			root.step(1);
			return;
		}

		root.origin = ToplevelManager.activeToplevel;
		// Always the previous window. Every press starts from a freshly sorted
		// list rather than resuming where the last one stopped, so pressing
		// again returns you to where you just came from instead of carrying on
		// into the middle of the history. Walking further back is what holding
		// Alt and pressing Tab repeatedly is for.
		root.index = n > 1 ? 1 : 0;
		root.open = true;
	}

	function step(delta: int) {
		const n = root.windows.length;
		if (n === 0) return;
		root.index = ((root.index + delta) % n + n) % n;
	}

	// Activation and unmapping have to happen together, in this order.
	//
	// While this shell holds the keyboard the compositor refuses to activate
	// any window — asking repeatedly changes nothing — and once the overlay is
	// gone the request comes from an unfocused client and is refused again.
	// Only a request issued in the same breath as giving the keyboard back is
	// honoured, which is why focus can never move before the overlay closes,
	// and why closing promptly is the whole of making this feel immediate.
	// Split across ticks the request is simply dropped.
	function finish(target) {
		if (target) target.activate();
		root.open = false;
	}

	function commit() {
		root.finish(root.selected);
	}

	function cancel() {
		// Nothing has moved yet, so this just puts the original back.
		root.finish(root.origin);
	}

	function remember(window) {
		if (!window) return;
		root.order = [window, ...root.order.filter(w => w !== window)];
	}

	// ---- most-recently-used tracking ----
	Connections {
		target: ToplevelManager

		function onActiveToplevelChanged() {
			const active = ToplevelManager.activeToplevel;
			if (!active) return;
			// Only while the switcher is down, so the cards never move under
			// the selection. Focus lands the instant the overlay closes, so
			// this re-sorts immediately as the gesture ends and the next press
			// already sees the new order.
			if (root.open) return;
			root.order = [active, ...root.order.filter(w => w !== active)];
		}
	}

	// Triggered through a named pipe rather than `qs ipc`.
	//
	// The pipe is already open, so a keybind only has to echo one word into
	// it — where `qs ipc` starts an entire Qt process first, around 50ms of
	// it. That delay is the whole problem: the Tab press arrives before this
	// overlay exists and is lost, so holding Alt produced no events at all and
	// the switcher had to guess when to close. Opening in a few milliseconds
	// instead means the keyboard is ours before a key can plausibly be
	// released, and the release can simply be waited for.
	Process {
		id: trigger

		running: Config.switcher
		command: ["sh", "-c",
			'f="${XDG_RUNTIME_DIR:-/tmp}/quickshell-switcher"; '
			// Never replace an existing pipe: another instance may be reading
			// it, and swapping the inode underneath leaves it holding one that
			// nothing writes to.
			+ '[ -p "$f" ] || mkfifo -m 600 "$f" || exit 1; '
			// Opened read-write so it never reaches end-of-file, and exec'd so
			// the reader *is* this shell. A `while :; do cat; done` loop leaves
			// the cat behind as an orphan every time the config reloads, and
			// those orphans go on competing for messages a pipe delivers to
			// only one reader.
			+ 'exec cat 0<> "$f"']

		stdout: SplitParser {
			onRead: line => root.dispatch(line.trim())
		}
	}

	function dispatch(command: string) {
		if (command === "next") root.show();
		else if (command === "prev") root.open ? root.step(-1) : root.show();
		else if (command === "cancel") root.cancel();
	}

	IpcHandler {
		target: "switcher"

		function open(): void {
			root.show();
		}

		function next(): void {
			root.show();
		}

		function prev(): void {
			if (root.open) root.step(-1);
			else root.show();
		}

		function cancel(): void {
			root.cancel();
		}
	}
}
