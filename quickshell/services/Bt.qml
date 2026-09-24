pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
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
		return root.isKnown(device) ? "paired" : "";
	}

	function inFlight(device): bool {
		return device.pairing
			|| device.state === BluetoothDeviceState.Connecting
			|| device.state === BluetoothDeviceState.Disconnecting;
	}

	// One click does the obvious thing for whatever state the device is in.
	function activate(device) {
		if (root.inFlight(device)) return;
		if (device.connected) {
			device.disconnect();
		} else if (root.isKnown(device)) {
			device.connect();
		} else {
			// BlueZ connects on its own once pairing completes for most
			// devices; trusting it first stops it asking again next time.
			device.trusted = true;
			device.pair();
		}
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
