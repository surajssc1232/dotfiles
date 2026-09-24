pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi state, backed by NetworkManager through nmcli.
//
// Scanning only runs while the menu is open (see `active`), but the radio
// state and the current connection are tracked continuously off `nmcli
// monitor`, so the bar's icon is right without polling.
Singleton {
	id: root

	// Set by the dropdown while it is open: gates the scan loop.
	property bool active: false

	property bool wifiEnabled: true
	property bool scanning: false
	property string activeSsid: ""
	property int activeSignal: 0

	// [{ ssid, signal, secure, saved, active }], strongest first.
	property var networks: []
	property var savedNames: []

	// SSID an operation is currently running for, and the last failure.
	property string busySsid: ""
	property string errorSsid: ""
	property string errorText: ""

	readonly property bool connected: activeSsid !== ""
	readonly property bool busy: busySsid !== ""

	readonly property string device: "wlo1"

	function isSaved(ssid: string): bool {
		return savedNames.indexOf(ssid) !== -1;
	}

	// ---- actions ----

	function connectTo(ssid: string, password: string) {
		root.clearError();
		root.busySsid = ssid;
		// The password goes through the environment rather than argv:
		// /proc/<pid>/cmdline is world-readable, /proc/<pid>/environ is not.
		worker.environment = ({ WIFI_PASSWORD: password });
		worker.exec(ssid, 'nmcli device wifi connect "$1" password "$WIFI_PASSWORD"');
	}

	function activate(ssid: string) {
		root.clearError();
		root.busySsid = ssid;
		worker.environment = ({});
		// A stored profile is brought up by name; anything else (an open
		// network) is joined straight off the scan result.
		worker.exec(ssid, root.isSaved(ssid)
			? 'nmcli connection up id "$1"'
			: 'nmcli device wifi connect "$1"');
	}

	function disconnect() {
		if (!root.connected) return;
		root.clearError();
		root.busySsid = root.activeSsid;
		worker.environment = ({});
		worker.exec(root.activeSsid, 'nmcli connection down id "$1"');
	}

	function forget(ssid: string) {
		root.clearError();
		root.busySsid = ssid;
		worker.environment = ({});
		worker.exec(ssid, 'nmcli connection delete id "$1"');
	}

	function setWifiEnabled(on: bool) {
		root.clearError();
		root.wifiEnabled = on;   // optimistic; radioProbe corrects it
		toggle.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
		toggle.running = true;
	}

	function rescan() {
		if (!root.wifiEnabled || root.scanning) return;
		root.scanning = true;
		rescanner.running = true;
	}

	function clearError() {
		root.errorSsid = "";
		root.errorText = "";
	}

	function refresh() {
		radioProbe.running = true;
		savedProbe.running = true;
		listProbe.running = true;
	}

	// ---- one shared worker for the connect/disconnect/forget commands ----

	Process {
		id: worker

		property string ssid: ""

		function exec(forSsid: string, script: string) {
			ssid = forSsid;
			// Output and status are folded into one stream so the result can be
			// handled in a single place, once stdout has definitely closed.
			command = ["sh", "-c",
				'out=$(' + script + ' 2>&1); printf "%s\\n__rc=%s\\n" "$out" "$?"',
				"sh", forSsid];
			running = true;
		}

		stdout: StdioCollector {
			onStreamFinished: {
				const lines = text.trim().split("\n");
				let rc = 0;
				const message = [];
				for (const line of lines) {
					if (line.startsWith("__rc="))
						rc = parseInt(line.slice(5)) || 0;
					else if (line.trim())
						message.push(line.trim());
				}

				if (rc !== 0) {
					root.errorSsid = worker.ssid;
					root.errorText = message.length
						// nmcli prefixes its failures with "Error: ".
						? message[message.length - 1].replace(/^Error:\s*/, "")
						: "Failed to connect.";
				} else {
					root.clearError();
				}

				root.busySsid = "";
				worker.environment = ({});
				root.refresh();
			}
		}
	}

	Process {
		id: toggle
		onExited: root.refresh()
	}

	Process {
		id: rescanner
		// A rescan is refused if one just ran; that is not worth surfacing, the
		// cached list is still shown either way.
		command: ["nmcli", "device", "wifi", "rescan"]
		onExited: {
			root.scanning = false;
			listProbe.running = true;
		}
	}

	// ---- probes ----

	Process {
		id: radioProbe
		command: ["nmcli", "-t", "-f", "WIFI", "radio"]
		stdout: StdioCollector {
			onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
		}
	}

	Process {
		id: savedProbe
		command: ["nmcli", "-t", "-f", "TYPE,NAME", "connection", "show"]
		stdout: StdioCollector {
			onStreamFinished: {
				const names = [];
				for (const line of text.split("\n")) {
					// TYPE first so the name, which may itself contain an
					// escaped colon, is whatever is left of the line.
					const m = line.match(/^([^:]*):(.*)$/);
					if (m && m[1] === "802-11-wireless")
						names.push(root.unquote(m[2]));
				}
				root.savedNames = names;
			}
		}
	}

	Process {
		id: listProbe
		// SSID is placed last for the same reason as above.
		command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID",
			"device", "wifi", "list", "--rescan", "no"]

		stdout: StdioCollector {
			onStreamFinished: {
				const seen = ({});
				const out = [];
				let activeSsid = "";
				let activeSignal = 0;

				for (const line of text.split("\n")) {
					const m = line.match(/^(\*| ?):(\d+):([^:]*):(.*)$/);
					if (!m) continue;

					const ssid = root.unquote(m[4]);
					// Hidden networks come back with an empty SSID and cannot be
					// joined by name, so they are left out of the list.
					if (!ssid) continue;

					const entry = {
						ssid: ssid,
						signal: parseInt(m[2]) || 0,
						secure: m[3].trim() !== "",
						active: m[1] === "*",
						saved: root.isSaved(ssid)
					};

					if (entry.active) {
						activeSsid = ssid;
						activeSignal = entry.signal;
					}

					// The same network shows up once per band and per AP; keep
					// only the strongest sighting of each name.
					const prev = seen[ssid];
					if (prev === undefined) {
						seen[ssid] = out.length;
						out.push(entry);
					} else if (entry.signal > out[prev].signal || entry.active) {
						out[prev] = entry;
					}
				}

				out.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
				root.networks = out;
				root.activeSsid = activeSsid;
				root.activeSignal = activeSignal;
			}
		}
	}

	// nmcli's terse output escapes separators inside values.
	function unquote(value: string): string {
		return value.replace(/\\(.)/g, "$1");
	}

	// ---- change tracking ----

	// Follows NetworkManager's own event stream, so connecting or dropping out
	// from anywhere else is reflected without a polling loop.
	Process {
		id: monitor
		command: ["nmcli", "monitor"]
		running: true
		stdout: SplitParser {
			onRead: debounce.restart()
		}
	}

	// Events arrive in bursts during a state change; settle before re-reading.
	Timer {
		id: debounce
		interval: 400
		onTriggered: root.refresh()
	}

	// While the menu is open, keep asking for a fresh scan.
	Timer {
		interval: 10000
		repeat: true
		running: root.active && root.wifiEnabled
		onTriggered: root.rescan()
	}

	// And keep re-reading the result. NetworkManager fills its list over the
	// seconds *after* a scan is asked for, so reading once when the scan
	// command returns shows whatever was already known and misses everything
	// found a moment later — which is why a network you could see only ever
	// appeared on the second press of the refresh icon.
	//
	// This reads NM's cache rather than scanning, which is cheap enough to do
	// on a short cycle.
	Timer {
		interval: 2000
		repeat: true
		running: root.active && root.wifiEnabled
		onTriggered: listProbe.running = true
	}

	Component.onCompleted: root.refresh()
}
