pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Audio devices, on top of Quickshell's Pipewire binding.
//
// Device switching goes through preferredDefaultAudioSink/Source rather than
// shelling out to pactl, so it stays in-process and updates immediately.
Singleton {
	id: root

	// Real devices only: streams are individual applications, not hardware.
	readonly property var outputs: Pipewire.nodes.values.filter(
		n => n.audio && !n.isStream && n.isSink)
	readonly property var inputs: Pipewire.nodes.values.filter(
		n => n.audio && !n.isStream && !n.isSink)

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var source: Pipewire.defaultAudioSource

	// Keeps the default devices' volume and mute properties live.
	PwObjectTracker {
		objects: [root.sink, root.source].filter(n => n !== null)
	}

	function label(node): string {
		if (!node) return "None";
		return node.nickname || node.description || node.name || "Unknown";
	}

	function setOutput(node) {
		if (node) Pipewire.preferredDefaultAudioSink = node;
	}

	function setInput(node) {
		if (node) Pipewire.preferredDefaultAudioSource = node;
	}

	// ---- headsets ----
	// A headset is anything that is not the machine's own built-in audio:
	// bluetooth, USB, or an analog jack that the card reports separately.
	function isHeadset(node): bool {
		if (!node) return false;
		const p = node.properties ?? ({});
		const form = (p["device.form_factor"] ?? "").toLowerCase();
		if (form === "headset" || form === "headphone" || form === "hands-free")
			return true;

		const bus = (p["device.bus"] ?? "").toLowerCase();
		if (bus === "bluetooth" || bus === "usb") return true;

		const name = (node.name ?? "").toLowerCase();
		return name.indexOf("bluez") !== -1 || name.indexOf("headset") !== -1;
	}

	// The mic to use when recording is set to follow whatever is plugged in.
	readonly property var headsetMic: root.inputs.find(n => root.isHeadset(n)) ?? null
	readonly property bool headsetConnected: headsetMic !== null

	// Pipewire exposes a sink's loopback as "<sink>.monitor", which is how a
	// recorder captures what is coming out of the speakers. It is not listed
	// as a node of its own, so the name is derived.
	readonly property string monitorName: root.sink ? root.sink.name + ".monitor" : ""
}
