pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs

// Thin layer over Quickshell's BlueZ binding: ordering, labels and the
// connect/pair decision, so the widget itself stays presentational.
Singleton {
	id: root

	readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
	readonly property bool available: adapter !== null
	readonly property bool enabled: adapter?.enabled ?? false
	readonly property bool discovering: adapter?.discovering ?? false

	// Mid-flip states, so the toggle can show it is working.
	readonly property bool busy: adapter
		? adapter.state === BluetoothAdapterState.Enabling
			|| adapter.state === BluetoothAdapterState.Disabling
		: false
	readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked

	// defaultAdapter only appears once BlueZ has been walked over D-Bus, about
	// a second after startup. Assume an adapter exists until that has had time
	// to happen, so the bar does not visibly reflow just after login; machines
	// with no adapter settle to hidden instead.
	property bool settled: false
	readonly property bool present: available || !settled

	Timer {
		interval: 5000
		running: true
		onTriggered: root.settled = true
	}

	readonly property var all: adapter?.devices?.values ?? []
	readonly property var connectedDevices: all.filter(d => d.connected)

	// Known devices always, plus anything a running scan has turned up.
	// Sorted so the things you actually use stay at the top and unpaired
	// discoveries do not shuffle them around.
	readonly property var devices: {
		const list = root.all.filter(d => root.isKnown(d) || root.discovering);
		return list.sort((a, b) => (b.connected - a.connected)
			|| (root.isKnown(b) - root.isKnown(a))
			|| root.label(a).localeCompare(root.label(b)));
	}

	function isKnown(device): bool {
		return device.paired || device.bonded || device.trusted;
	}

	function label(device): string {
		return device.name || device.deviceName || device.address;
	}

	function icon(device): string {
		return Config.icons.device[device.icon] ?? Config.icons.device["unknown"];
	}

	// What the row says under/next to the name.
	function status(device): string {
		if (device.pairing) return "pairing…";
		switch (device.state) {
		case BluetoothDeviceState.Connecting: return "connecting…";
		case BluetoothDeviceState.Disconnecting: return "disconnecting…";
		case BluetoothDeviceState.Connected:
			return device.batteryAvailable
				? Math.round(device.battery * 100) + "%"
				: "connected";
		}
		const failed = root.failures[device.address];
		if (failed) return failed;
		return root.isKnown(device) ? "paired" : "";
	}

	// ---- failures ----
	//
	// BlueZ reports a failed connect or pair only as the device quietly
	// falling back to where it was. Watching each device's transitions turns
	// that into something a row can say, until the next attempt clears it.
	property var failures: ({})

	function setFailure(address: string, text: string) {
		const next = Object.assign({}, root.failures);
		if (text) next[address] = text;
		else delete next[address];
		root.failures = next;
	}

	Instantiator {
		model: root.all

		delegate: Connections {
			required property var modelData
			property bool wasConnecting: false
			property bool wasPairing: false

			target: modelData

			function onStateChanged() {
				const s = modelData.state;
				if (s === BluetoothDeviceState.Connecting) {
					wasConnecting = true;
				} else if (s === BluetoothDeviceState.Connected) {
					wasConnecting = false;
					root.setFailure(modelData.address, "");
				} else if (s === BluetoothDeviceState.Disconnected && wasConnecting) {
					wasConnecting = false;
					root.setFailure(modelData.address, "couldn't connect");
				}
			}

			function onPairingChanged() {
				if (modelData.pairing) {
					wasPairing = true;
				} else if (wasPairing) {
					wasPairing = false;
					root.setFailure(modelData.address, modelData.paired ? "" : "pairing failed");
				}
			}
		}
	}

	function inFlight(device): bool {
		return device.pairing
			|| device.state === BluetoothDeviceState.Connecting
			|| device.state === BluetoothDeviceState.Disconnecting;
	}

	// One click does the obvious thing for whatever state the device is in.
	function activate(device) {
		if (root.inFlight(device)) return;
		root.setFailure(device.address, "");
		if (device.connected) {
			device.disconnect();
		} else if (root.isKnown(device)) {
			device.connect();
		} else {
			// BlueZ connects on its own once pairing completes for most
			// devices; trusting it first stops it asking again next time.
			device.trusted = true;
			root.pairingAddress = device.address;
			device.pair();
		}
	}

	// ---- pairing agent ----
	//
	// pair() alone is not enough: BlueZ hands the device's "accept pairing?",
	// "confirm this code" and "type this code" requests to a registered agent,
	// and with none running most keyboards just time out. bluetoothctl is that
	// agent here, but it never answers on its own: every request is exposed as
	// `request` and waits for a choice in BluetoothPrompt.
	//
	// request.kind is one of
	//   "authorize" — device asks to pair, nothing to compare        (yes/no)
	//   "confirm"   — both sides show request.code; check they match (yes/no)
	//   "display"   — type request.code on the device, then Enter   (cancel only)
	//   "pin"       — device wants a PIN/passkey typed here          (text)
	//   "service"   — paired device asks to use a profile            (yes/no)
	property var request: null

	// Last device to start pairing from the widget; only used to name the
	// device in the prompt, never to decide anything.
	property string pairingAddress: ""

	function requestDevice(): var {
		return root.all.find(d => d.address === root.pairingAddress && d.pairing)
			?? root.all.find(d => d.pairing)
			?? null;
	}

	function ask(kind: string, code: string) {
		const device = root.requestDevice();
		root.request = {
			kind: kind,
			code: code,
			address: device?.address ?? "",
			name: device ? root.label(device) : "Unknown device",
		};
	}

	function accept() {
		if (!root.request) return;
		if (root.request.kind !== "display") agent.write("yes\n");
		root.request = null;
	}

	function reject() {
		if (!root.request) return;
		if (root.request.kind === "display" || root.request.kind === "pin") {
			if (root.request.address !== "")
				agent.write("cancel-pairing " + root.request.address + "\n");
			if (root.request.kind === "pin") agent.write("\n");
		} else {
			agent.write("no\n");
		}
		root.request = null;
	}

	function answerPin(pin: string) {
		if (!root.request || root.request.kind !== "pin") return;
		agent.write(pin + "\n");
		root.request = null;
	}

	Process {
		id: agent

		command: ["bluetoothctl"]
		running: root.available
		stdinEnabled: true

		onStarted: {
			agent.write("agent KeyboardDisplay\n");
			agent.write("default-agent\n");
		}

		stdout: SplitParser {
			onRead: data => {
				const line = data.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "");
				let m;
				if ((m = line.match(/Confirm passkey (\d+)/i)))
					root.ask("confirm", m[1]);
				else if (/Accept pairing/i.test(line))
					root.ask("authorize", "");
				else if (/Authorize service/i.test(line))
					root.ask("service", "");
				else if (/Enter (PIN code|passkey)/i.test(line))
					root.ask("pin", "");
				else if ((m = line.match(/(?:Passkey|PIN code):\s*(\d+)/i)))
					root.ask("display", m[1]);
				else if (/Request canceled|Pairing successful|Failed to pair/i.test(line))
					root.request = null;
			}
		}

		// bluetoothd restarting kills the agent with it; come back.
		onExited: {
			root.request = null;
			if (root.available) restartAgent.start();
		}
	}

	Timer {
		id: restartAgent
		interval: 2000
		onTriggered: agent.running = true
	}

	// A "type this code" prompt has nothing to answer, so it is closed by the
	// device itself finishing.
	onConnectedDevicesChanged: {
		if (root.request?.kind === "display"
				&& root.connectedDevices.some(d => d.address === root.request.address && d.paired))
			root.request = null;
	}

	// A soft block (airplane mode, the rfkill key) is the user's to lift; a
	// hard block is a physical switch and this can do nothing about it.
	function unblock() {
		Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
	}

	function setEnabled(on: bool) {
		if (root.adapter) root.adapter.enabled = on;
	}

	function setDiscovering(on: bool) {
		if (root.adapter && root.enabled) root.adapter.discovering = on;
	}

	// Scanning burns power and the radio, so it is never left running.
	function stopDiscovery() {
		root.setDiscovering(false);
	}
}
