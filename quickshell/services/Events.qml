pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Reminders and meetings, added from the calendar by right-clicking a day.
//
// Kept in a file of their own under the shell's state directory rather than
// in Persist: this is a list that grows, not a handful of toggles, and it is
// rewritten on every add and delete.
//
// An entry with a time raises a notification when that time arrives. One
// without is an all-day note: it marks the day and is never announced.
//
// A repeating entry is stored once, with the date it starts on, and every
// day works out for itself whether it falls on it. Nothing is ever copied
// forward, so there is no end to a series and nothing to prune.
Singleton {
	id: root

	// [{ id, date: "yyyy-MM-dd", time: "HH:mm" | "", title, kind, repeat,
	//    lastNotified: "yyyy-MM-dd" | "" }]
	// kind is "reminder" or "meeting"; repeat is one of `repeats` below.
	// lastNotified is the latest occurrence already announced.
	property var events: []

	readonly property var repeats: ["none", "daily", "weekly", "monthly", "yearly"]
	readonly property var repeatNames: ({
		none: "Once", daily: "Daily", weekly: "Weekly", monthly: "Monthly", yearly: "Yearly"
	})

	function key(d: date): string {
		return Qt.formatDate(d, "yyyy-MM-dd");
	}

	function parse(dateKey: string): date {
		const [y, m, d] = dateKey.split("-").map(Number);
		return new Date(y, m - 1, d);
	}

	function daysIn(year: int, month: int): int {
		return new Date(year, month + 1, 0).getDate();
	}

	// Whether an entry falls on a day. A monthly entry on the 31st lands on
	// the last day of shorter months, and a yearly one on 29 February lands
	// on the 28th in other years, rather than silently skipping them.
	function occursOn(e, dateKey: string): bool {
		if (dateKey < e.date) return false;
		if (dateKey === e.date) return true;

		const start = root.parse(e.date);
		const day = root.parse(dateKey);

		switch (e.repeat) {
		case "daily":
			return true;
		case "weekly":
			return day.getDay() === start.getDay();
		case "monthly":
			return day.getDate() === Math.min(start.getDate(),
				root.daysIn(day.getFullYear(), day.getMonth()));
		case "yearly":
			return day.getMonth() === start.getMonth()
				&& day.getDate() === Math.min(start.getDate(),
					root.daysIn(day.getFullYear(), day.getMonth()));
		default:
			return false;
		}
	}

	// Whether anything is on a day. Reads `events`, so a binding that calls
	// it is re-evaluated whenever the list changes.
	function hasOn(dateKey: string): bool {
		return root.events.some(e => root.occursOn(e, dateKey));
	}

	// A day's events, all-day ones first and then timed ones in order.
	function on(dateKey: string): var {
		return root.events
			.filter(e => root.occursOn(e, dateKey))
			.sort((a, b) => (a.time || "").localeCompare(b.time || ""));
	}

	// The two days whose occurrences can still be due: today, and yesterday
	// for anything missed across midnight inside the twelve-hour window.
	function recentDays(): var {
		const now = new Date();
		const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
		return [root.key(now), root.key(yesterday)];
	}

	// The latest occurrence that is already in the past, so a new entry is
	// not announced the moment it is saved for a time that has gone by.
	function lastPast(e): string {
		if (!e.time) return "";
		for (const day of root.recentDays()) {
			if (root.occursOn(e, day) && root.dueAt(day, e.time) <= Date.now()) return day;
		}
		return "";
	}

	// Accepts "9", "930", "9:30", "09:30". Anything else is no time at all,
	// rather than a guess: a reminder at the wrong time is worse than an
	// all-day one.
	function normaliseTime(text: string): string {
		const t = (text ?? "").trim();
		if (!t) return "";
		const m = t.match(/^(\d{1,2})(?::?(\d{2}))?$/);
		if (!m) return "";
		const h = parseInt(m[1]);
		const min = m[2] === undefined ? 0 : parseInt(m[2]);
		if (h > 23 || min > 59) return "";
		return String(h).padStart(2, "0") + ":" + String(min).padStart(2, "0");
	}

	function add(dateKey: string, time: string, title: string, kind: string, repeat: string) {
		const name = (title ?? "").trim();
		if (!name) return;

		const at = root.normaliseTime(time);
		const entry = {
			id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
			date: dateKey,
			time: at,
			title: name,
			kind: kind === "meeting" ? "meeting" : "reminder",
			repeat: root.repeats.indexOf(repeat) !== -1 ? repeat : "none",
			lastNotified: ""
		};
		entry.lastNotified = root.lastPast(entry);

		root.events = root.events.concat([entry]);
		root.save();
	}

	function remove(id: string) {
		root.events = root.events.filter(e => e.id !== id);
		root.save();
	}

	function dueAt(dateKey: string, time: string): real {
		const [y, mo, d] = dateKey.split("-").map(Number);
		const [h, mi] = time.split(":").map(Number);
		return new Date(y, mo - 1, d, h, mi).getTime();
	}

	function save() {
		store.setText(JSON.stringify(root.events));
	}

	// Announces whatever has come due. Also catches anything that fell due
	// while the machine was asleep or the shell was not running, as long as
	// it is from the last twelve hours; older than that is just stale.
	function check() {
		const now = Date.now();
		const days = root.recentDays();
		let changed = false;

		const next = root.events.map(e => {
			if (!e.time) return e;

			// Oldest first, so if both yesterday's and today's are due only
			// the newer one is left as the mark.
			let result = e;
			for (const day of days.slice().reverse()) {
				if (!root.occursOn(e, day)) continue;
				if (day <= (result.lastNotified || "")) continue;

				const due = root.dueAt(day, e.time);
				if (due > now) continue;

				if (now - due < 12 * 3600 * 1000) {
					const repeat = e.repeat && e.repeat !== "none"
						? " · repeats " + root.repeatNames[e.repeat].toLowerCase() : "";
					Quickshell.execDetached({
						command: ["notify-send",
							"-a", "Calendar",
							"-u", e.kind === "meeting" ? "critical" : "normal",
							(e.kind === "meeting" ? "Meeting: " : "Reminder: ") + e.title,
							e.time + " · " + Qt.formatDate(new Date(due), "dddd d MMMM") + repeat]
					});
				}
				result = Object.assign({}, result, { lastNotified: day });
				changed = true;
			}
			return result;
		});

		if (changed) {
			root.events = next;
			root.save();
		}
	}

	FileView {
		id: store

		path: Quickshell.statePath("events")
		blockLoading: true
		printErrors: false
	}

	// Aligned to nothing in particular; every 20s is close enough that a
	// reminder is never more than a moment late.
	Timer {
		interval: 20000
		repeat: true
		running: true
		triggeredOnStart: true
		onTriggered: root.check()
	}

	Component.onCompleted: {
		try {
			const saved = JSON.parse(store.text().trim() || "[]");
			// Entries from before repeats existed carried a notified flag
			// instead of the date of the last announcement.
			if (Array.isArray(saved)) root.events = saved.map(e => Object.assign({
				repeat: "none",
				lastNotified: e.notified ? e.date : ""
			}, e));
		} catch (err) {
			root.events = [];
		}
	}
}
