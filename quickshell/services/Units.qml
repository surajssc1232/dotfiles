pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Watches for systemd units that have failed.
//
// On NixOS you normally discover a broken service by noticing something it was
// supposed to be doing is not happening. This says so instead, once, when it
// happens — and the launcher's % mode lists them so one can be restarted
// without going to find the right systemctl incantation.
Singleton {
	id: root

	// [{ unit, scope, description }] — scope is "system" or "user".
	property var failed: []

	readonly property int count: root.failed.length

	// Units already reported, so a unit that stays broken is not announced
	// every minute for the rest of the session.
	property var announced: ({})

	// The first look is a summary rather than one notification per unit: a
	// machine that booted with three failures should say so once.
	property bool primed: false

	function refresh() {
		if (!probe.running) probe.running = true;
	}

	function restart(entry) {
		if (!entry) return;

		if (entry.scope === "user") {
			Quickshell.execDetached({
				command: ["systemctl", "--user", "restart", entry.unit]
			});
			recheck.restart();
			return;
		}

		// A system unit needs root, and asking for a password from a layer
		// surface is not something to invent — this opens a terminal where
		// sudo can prompt properly.
		Quickshell.execDetached({
			command: Config.terminal.concat(["sh", "-c",
				'sudo systemctl restart "$1"; echo; echo "[enter to close]"; read _',
				"sh", entry.unit])
		});
		recheck.restart();
	}

	function journal(entry) {
		if (!entry) return;
		const args = entry.scope === "user"
			? ["journalctl", "--user", "-u", entry.unit, "-n", "200", "--no-pager"]
			: ["journalctl", "-u", entry.unit, "-n", "200", "--no-pager"];

		Quickshell.execDetached({
			command: Config.terminal.concat(["sh", "-c",
				'"$@" | less +G', "sh"]).concat(args)
		});
	}

	function announce(entries) {
		if (!root.primed) {
			root.primed = true;
			if (entries.length > 0) {
				Quickshell.execDetached({
					command: ["notify-send", "-u", "critical", "-a", "systemd",
						entries.length === 1
							? "1 unit has failed"
							: entries.length + " units have failed",
						entries.map(e => e.unit).join(", ")]
				});
			}
			for (const entry of entries) root.announced[entry.unit] = true;
			return;
		}

		for (const entry of entries) {
			if (root.announced[entry.unit]) continue;
			root.announced[entry.unit] = true;
			Quickshell.execDetached({
				command: ["notify-send", "-u", "critical", "-a", "systemd",
					"Unit failed: " + entry.unit,
					entry.description || entry.scope + " unit"]
			});
		}
	}

	Process {
		id: probe

		// Both scopes in one pass, each line tagged with where it came from.
		command: ["sh", "-c",
			'systemctl --failed --no-legend --plain 2>/dev/null | sed "s/^/system /"; '
			+ 'systemctl --user --failed --no-legend --plain 2>/dev/null | sed "s/^/user /"']

		stdout: StdioCollector {
			onStreamFinished: {
				const found = [];
				for (const line of text.split("\n")) {
					const parts = line.trim().split(/\s+/);
					// scope unit load active sub description…
					if (parts.length < 5) continue;
					found.push({
						scope: parts[0],
						unit: parts[1],
						description: parts.slice(5).join(" ")
					});
				}

				root.failed = found;

				// Anything that recovered can be announced again if it breaks
				// a second time.
				const live = found.map(e => e.unit);
				const kept = ({});
				for (const unit of Object.keys(root.announced))
					if (live.indexOf(unit) !== -1) kept[unit] = true;
				root.announced = kept;

				root.announce(found);
			}
		}
	}

	// Shortly after a restart, to pick up whether it worked.
	Timer {
		id: recheck

		interval: 2500
		onTriggered: root.refresh()
	}

	Timer {
		interval: 60000
		repeat: true
		running: true
		triggeredOnStart: true
		onTriggered: root.refresh()
	}
}
