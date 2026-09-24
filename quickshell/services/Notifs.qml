pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

	readonly property int historyLimit: 50
	readonly property int defaultTimeout: 5000
	readonly property int criticalTimeout: 0     // 0 = stays until dismissed

	readonly property int count: history.length

	NotificationServer {
		id: server

		// Advertised over D-Bus so senders know what the bar can render.
		bodySupported: true
		bodyMarkupSupported: true
		actionsSupported: true
		imageSupported: true
		persistenceSupported: true

		onNotification: notification => {
			// Tracked notifications survive past the callback so they can be
			// held in the history list and acted on later.
			notification.tracked = true;

			// A notification can also be closed by the sender, or torn down on
			// shutdown. Drop our references when that happens, or the lists
			// keep pointing at a destroyed object and acting on it errors.
			notification.closed.connect(() => root.forget(notification));

			root.history = [notification, ...root.history].slice(0, root.historyLimit);

			if (root.bootWindow) root.record(notification);

			// transient notifications (progress bars, volume OSDs) are meant
			// to flash and vanish, and never belong in a toast stack.
			if (!root.dnd && !notification.transient)
				root.popups = [notification, ...root.popups];
		}
	}

	function timeoutFor(n): int {
		if (n.urgency === NotificationUrgency.Critical) return root.criticalTimeout;
		return n.expireTimeout > 0 ? n.expireTimeout : root.defaultTimeout;
	}

	// Drop all references without touching the notification itself.
	function forget(n) {
		root.popups = root.popups.filter(p => p !== n);
		root.history = root.history.filter(p => p !== n);
	}

	// Take a notification off the toast stack but keep it in history.
	function hidePopup(n) {
		root.popups = root.popups.filter(p => p !== n);
	}

	// Remove entirely: closes it over D-Bus so the sending app knows.
	function dismiss(n) {
		hidePopup(n);
		root.history = root.history.filter(p => p !== n);
		n.dismiss();
	}

	function clearAll() {
		// Copy first: dismiss() fires closed(), which calls forget() and
		// mutates the very lists being iterated.
		const all = [...root.history];
		root.popups = [];
		root.history = [];
		for (const n of all) n.dismiss();
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
