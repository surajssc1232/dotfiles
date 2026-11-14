pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri's workspaces and the windows on them, kept live.
//
// `niri msg -j event-stream` prints a line for every change. Rather than
// replaying each event type into a local model, any event just schedules a
// fresh `niri msg -j workspaces` + `windows` read: two small JSON dumps, and
// the state can never drift from what niri actually has.
Singleton {
	id: root

	// [{ id, idx, name, output, is_active, is_focused, is_urgent, active_window_id }]
	property var workspaces: []
	// [{ id, app_id, title, workspace_id, is_focused }]
	property var windows: []

	readonly property bool available: root.workspaces.length > 0

	// Workspaces on one output, in niri's order, each with its windows.
	function on(output: string): var {
		return root.workspaces
			.filter(w => w.output === output)
			.sort((a, b) => a.idx - b.idx)
			.map(w => ({
				id: w.id,
				idx: w.idx,
				name: w.name,
				active: w.is_active,
				focused: w.is_focused,
				urgent: w.is_urgent,
				windows: root.windows.filter(x => x.workspace_id === w.id)
			}));
	}

	function focus(ws) {
		// focus-workspace by index acts on the focused monitor, so on a
		// second screen the monitor has to be focused first.
		// focus-monitor also warps the pointer to that monitor's centre, so
		// it is only sent when the workspace really is on another one.
		const out = root.workspaces.find(w => w.id === ws.id)?.output ?? "";
		const current = root.workspaces.find(w => w.is_focused)?.output ?? "";
		Quickshell.execDetached({ command: ["sh", "-c",
			'[ -n "$1" ] && niri msg action focus-monitor "$1"; niri msg action focus-workspace "$2"',
			"sh", out !== current ? out : "", String(ws.idx)] });
	}

	function focusWindow(id: int) {
		Quickshell.execDetached({ command: ["niri", "msg", "action", "focus-window", "--id", String(id)] });
	}

	Process {
		id: stream

		running: true
		command: ["niri", "msg", "-j", "event-stream"]

		stdout: SplitParser {
			onRead: _ => debounce.restart()
		}

		// niri restarting, or not running yet at login: try again shortly.
		onExited: retry.start()
	}

	Timer {
		id: retry
		interval: 3000
		onTriggered: stream.running = true
	}

	// Events arrive in bursts (a window opening is several), so they are
	// coalesced into one read.
	Timer {
		id: debounce
		interval: 40
		onTriggered: fetch.running = true
	}

	Process {
		id: fetch

		command: ["sh", "-c", "niri msg -j workspaces; echo; niri msg -j windows"]

		stdout: StdioCollector {
			onStreamFinished: {
				const parts = this.text.trim().split("\n").filter(l => l.trim().length > 0);
				if (parts.length < 2) return;
				try {
					root.workspaces = JSON.parse(parts[0]);
					root.windows = JSON.parse(parts[1]);
				} catch (err) {}
			}
		}
	}
}
