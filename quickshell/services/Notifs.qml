pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import Quickshell.Services.Notifications
import qs.services

// Owns org.freedesktop.Notifications. Nothing else on this system claims it
// (no mako/dunst/swaync), so the bar can serve notifications directly.
Singleton {
	id: root

	// Toasts currently on screen, newest first.
	property var popups: []

	// Everything received this session, newest first, capped.
	property var history: []

	property bool dnd: false

	// When a compositor screenshot was last announced, so the notification
	// the shell sends for the copied image can call it a screenshot rather
	// than guessing.
	property real lastScreenshotAt: 0

	readonly property int historyLimit: 50
	readonly property int defaultTimeout: 2000
	readonly property int criticalTimeout: 0     // 0 = stays until dismissed

	// Kept from previous sessions: plain records, not live notifications.
	// They cannot be acted on any more — the app that sent them is long gone —
	// but "what did that say?" outliving a reboot is the whole point.
	property var archive: []

	// What the history list shows: this session first, then everything before
	// that is not already in it.
	//
	// The de-duplication matters on a config reload, where the live
	// notifications survive but the archive is read back from disk as well —
	// without this, every reload showed the same notification twice more.
	readonly property var entries: {
		const live = root.history;
		const seen = live.map(n => root.identity(n));
		return live.concat(root.archive.filter(r => seen.indexOf(root.identity(r)) === -1));
	}

	function identity(n): string {
		return (n.appName ?? "") + "\u0000" + (n.summary ?? "") + "\u0000" + (n.body ?? "");
	}

	readonly property int count: root.entries.length

	NotificationServer {
		id: server

		// Advertised over D-Bus so senders know what the bar can render.
		bodySupported: true
		bodyMarkupSupported: true
		actionsSupported: true
		imageSupported: true
		persistenceSupported: true

		onNotification: notification => {
			// niri announces its own screenshots with no image attached. Ours
			// carries the thumbnail, so this one is dropped rather than
			// showing you the same event twice.
			if (Config.screenshotPreview
					&& (notification.appName ?? "").toLowerCase() === "niri"
					&& /screenshot/i.test(notification.summary ?? "")) {
				root.lastScreenshotAt = Date.now();
				return;
			}

			// Tracked notifications survive past the callback so they can be
			// held in the history list and acted on later.
			notification.tracked = true;

			// A notification can also be closed by the sender, or torn down on
			// shutdown. Drop our references when that happens, or the lists
			// keep pointing at a destroyed object and acting on it errors.
			notification.closed.connect(() => root.forget(notification));

			root.history = [notification, ...root.history].slice(0, root.historyLimit);

			if (root.bootWindow) root.record(notification);

			root.save();

			// transient notifications (progress bars, volume OSDs) are meant
			// to flash and vanish, and never belong in a toast stack.
			if (!root.dnd && !notification.transient)
				root.popups = [notification, ...root.popups];
		}
	}

	// Capped rather than merely defaulted: an application asking for ten
	// seconds still gets two. Critical is the one exception — something that
	// says the battery is about to die should wait to be acknowledged.
	function timeoutFor(n): int {
		if (n.urgency === NotificationUrgency.Critical) return root.criticalTimeout;
		return n.expireTimeout > 0
			? Math.min(n.expireTimeout, root.defaultTimeout)
			: root.defaultTimeout;
	}

	// A live notification reduced to the parts worth keeping. Actions are
	// dropped deliberately: invoking one after the sender has exited does
	// nothing, and a button that does nothing is worse than no button.
	function snapshot(n) {
		return ({
			urgency: n.urgency,
			image: n.image ?? "",
			appIcon: n.appIcon ?? "",
			summary: n.summary ?? "",
			appName: n.appName ?? "",
			body: n.body ?? "",
			actions: []
		});
	}

	function save() {
		saveDelay.restart();
	}

	// Drop all references without touching the notification itself.
	function forget(n) {
		root.popups = root.popups.filter(p => p !== n);
		root.leaving = root.leaving.filter(p => p !== n);
		root.arrived = root.arrived.filter(p => p !== n);
		root.history = root.history.filter(p => p !== n);
		root.save();
	}

	// Toasts on their way out. A delegate is destroyed the instant it leaves
	// the model, so there is nothing left to animate — the notification is
	// marked instead, the card fades, and the sweep below drops it once the
	// fade has had time to run.
	property var leaving: []

	// Which toasts have already played their entrance. The popup list is a
	// plain array, so every change to it rebuilds all of the delegates — and
	// without this a second notification made the first one fade in again.
	property var arrived: []

	function hasArrived(n): bool {
		return root.arrived.indexOf(n) !== -1;
	}

	function markArrived(n) {
		if (root.hasArrived(n)) return;
		root.arrived = [...root.arrived, n];
	}

	readonly property int fadeOut: 260

	function hidePopup(n) {
		if (root.leaving.indexOf(n) !== -1) return;
		root.leaving = [...root.leaving, n];
		sweep.restart();
	}

	Timer {
		id: sweep

		interval: root.fadeOut
		onTriggered: {
			root.popups = root.popups.filter(p => root.leaving.indexOf(p) === -1);
			root.leaving = [];
			// Nothing on screen needs remembering.
			root.arrived = root.arrived.filter(n => root.popups.indexOf(n) !== -1);
		}
	}

	// Remove entirely: closes it over D-Bus so the sending app knows.
	function dismiss(n) {
		root.hidePopup(n);
		root.history = root.history.filter(p => p !== n);
		root.archive = root.archive.filter(p => p !== n);
		// Restored records have no sender to tell.
		if (n.dismiss) n.dismiss();
		root.save();
	}

	function clearAll() {
		// Copy first: dismiss() fires closed(), which calls forget() and
		// mutates the very lists being iterated.
		const all = [...root.history];
		root.popups = [];
		root.history = [];
		root.archive = [];
		for (const n of all) n.dismiss();
		root.save();
	}

	// ---- boot-time capture ----
	//
	// Something sends a notification on the first boot and it cannot be traced
	// afterwards: notifications travel over D-Bus and leave nothing in the
	// journal. Anything arriving in the first two minutes of a session is
	// written down here so the next boot names the sender.
	//
	// App name, summary and time only — never the body, which is where the
	// contents of your messages would be. Delete this block once it has done
	// its job.
	property bool bootWindow: true
	property var bootLog: []

	readonly property int bootLogLimit: 50

	function record(n) {
		root.bootLog = [({
			at: new Date().toISOString(),
			app: n.appName,
			summary: n.summary
		}), ...root.bootLog].slice(0, root.bootLogLimit);
		bootFile.setText(JSON.stringify(root.bootLog, null, 1));
	}

	Timer {
		interval: 120000
		running: true
		onTriggered: root.bootWindow = false
	}

	// Written on a short delay: a burst of notifications would otherwise be a
	// burst of file writes.
	Timer {
		id: saveDelay

		interval: 600
		onTriggered: {
			// entries, not history: already de-duplicated, and it carries the
			// older records forward instead of dropping them.
			const records = root.entries.map(n => root.snapshot(n))
				.slice(0, root.historyLimit);
			historyFile.setText(JSON.stringify(records));
		}
	}

	FileView {
		id: historyFile

		path: Quickshell.statePath("notifications")
		blockLoading: true
		printErrors: false
	}

	FileView {
		id: bootFile

		path: Quickshell.statePath("boot-notifications")
		blockLoading: true
		printErrors: false
	}

	// The history panel hangs off the bell in the bar, so a keybind cannot
	// reach it directly — it asks here and the panel listens.
	signal centerToggled()
	signal centerClosed()

	function toggleDnd() {
		root.dnd = !root.dnd;
		if (root.dnd) root.popups = [];
		Persist.set("dnd", root.dnd);
	}

	// Silence is a choice you make once and expect to hold, so it outlives
	// the session that made it.
	Component.onCompleted: {
		root.dnd = Persist.get("dnd", false);
		try {
			const saved = JSON.parse(bootFile.text().trim() || "[]");
			if (Array.isArray(saved)) root.bootLog = saved;
		} catch (err) {
			root.bootLog = [];
		}

		try {
			const past = JSON.parse(historyFile.text().trim() || "[]");
			if (Array.isArray(past)) root.archive = past;
		} catch (err) {
			root.archive = [];
		}
	}

	IpcHandler {
		target: "notifs"

		function toggle(): void {
			root.centerToggled();
		}

		function close(): void {
			root.centerClosed();
		}

		function dnd(): void {
			root.toggleDnd();
		}

		function clear(): void {
			root.clearAll();
		}
	}
}
