pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

	// Individual applications playing audio. A playback stream reports itself
	// as a sink — it is the thing a sink plays — which is what separates it
	// from a capture stream rather than from hardware.
	readonly property var streams: Pipewire.nodes.values.filter(
		n => n.audio && n.isStream && n.isSink && !root.ours(n))

	// The shell's own streams: every level meter in the mixer is a small
	// capture stream named after this process. Listing them as apps made the
	// mixer show a row per meter, whose meter made another stream, and so on.
	function ours(n): bool {
		return /quickshell/i.test(n?.name ?? "")
			|| /quickshell/i.test((n?.properties ?? ({}))["application.name"] ?? "");
	}

	// Keeps the default devices' volume and mute properties live.
	PwObjectTracker {
		objects: [root.sink, root.source].filter(n => n !== null)
	}

	// And the same for every application stream, or their sliders would sit
	// at whatever value they held when the panel opened.
	PwObjectTracker {
		objects: root.streams
	}

	// What to call an application: the name it registered under, then what it
	// says it is playing where that adds anything. Most browsers call every
	// stream "Playback", which on its own names nothing at all.
	function streamLabel(node): string {
		if (!node) return "Unknown";
		const p = node.properties ?? ({});
		const app = p["application.name"] || node.description || node.name || "";
		const media = p["media.name"] || "";
		if (!app) return media || "Unknown";

		const generic = /^(playback|audio stream|audio-src|output|audio)$/i.test(media);
		return media && !generic && media.toLowerCase() !== app.toLowerCase()
			? app + " \u00b7 " + media
			: app;
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

	// ---- mixer ----
	// Everything below serves the mixer (modules/AudioMixer.qml), which
	// replaces pavucontrol. Volumes, mutes and defaults go through the
	// Pipewire binding; moving a stream, ports and card profiles are not in it,
	// so those go through pactl (pipewire-pulse), whose stream numbers are
	// each node's object.serial.

	// Applications recording: what is using the microphone right now.
	// Peak meters and level probes are streams too, and are left out.
	readonly property var recorders: Pipewire.nodes.values.filter(
		n => n.audio && n.isStream && !n.isSink && !root.ours(n)
			&& (n.properties ?? ({}))["stream.monitor"] !== "true")

	PwObjectTracker {
		objects: root.outputs.concat(root.inputs, root.recorders)
	}

	// The device a stream is playing to, or recording from: the other end of
	// its link.
	function deviceOf(stream): var {
		if (!stream) return null;
		for (const g of Pipewire.linkGroups.values) {
			if (stream.isSink && g.source === stream && g.target && !g.target.isStream) return g.target;
			if (!stream.isSink && g.target === stream && g.source && !g.source.isStream) return g.source;
		}
		return null;
	}

	function serial(node): string {
		return String((node?.properties ?? ({}))["object.serial"] ?? "");
	}

	// Sends a playing app to another output, or a recording app to another
	// input. pipewire-pulse remembers the choice for that app next time.
	function moveStream(stream, device) {
		if (!stream || !device) return;
		const id = root.serial(stream);
		if (!id) return;
		root.pactl([stream.isSink ? "move-sink-input" : "move-source-output", id, device.name]);
	}

	// An icon for an application stream: the one it asks for, else its
	// program's, else whatever app of that name is installed.
	function streamIcon(node): string {
		const p = node?.properties ?? ({});
		const tries = [p["application.icon_name"], p["application.process.binary"],
			(p["application.name"] ?? "").toLowerCase()];
		for (const t of tries) {
			if (!t) continue;
			const path = Quickshell.iconPath(t, true);
			if (path) return path;
		}
		const e = p["application.name"] ? DesktopEntries.heuristicLookup(p["application.name"]) : null;
		return e?.icon ? Quickshell.iconPath(e.icon, true) : "";
	}

	// Left/right balance from -1 (all left) to 1 (all right), for stereo nodes.
	function balance(node): real {
		const v = node?.audio?.volumes ?? [];
		if (v.length !== 2) return 0;
		const top = Math.max(v[0], v[1]);
		if (top <= 0) return 0;
		return v[0] >= v[1] ? -(1 - v[1] / top) : (1 - v[0] / top);
	}

	function setBalance(node, b: real) {
		const a = node?.audio;
		if (!a || (a.volumes ?? []).length !== 2) return;
		const top = Math.max(a.volumes[0], a.volumes[1]);
		a.volumes = [top * Math.min(1, 1 - b), top * Math.min(1, 1 + b)];
	}

	// Asks the volume pill on the focused bar to open or close the mixer;
	// for keybinds: qs ipc call mixer toggle.
	signal mixerToggleRequested()

	IpcHandler {
		target: "mixer"
		function toggle(): void { root.mixerToggleRequested(); }
	}

	// ---- ports and profiles (through pactl) ----

	// { nodeName: { active, ports: [{ name, description, available }] } }
	property var ports: ({})
	// [{ name, description, active, profiles: [{ name, description, available }] }]
	property var cards: []

	function pactl(args) {
		Quickshell.execDetached({ command: ["pactl"].concat(args) });
		refreshSoon.restart();
	}

	function setPort(node, port: string) {
		if (!node) return;
		root.pactl([node.isSink ? "set-sink-port" : "set-source-port", node.name, port]);
	}

	function setProfile(card: string, profile: string) {
		root.pactl(["set-card-profile", card, profile]);
	}

	function refresh() {
		if (!probe.running) probe.running = true;
	}

	Timer {
		id: refreshSoon
		interval: 400
		onTriggered: root.refresh()
	}

	// A device appearing or going (a headset connecting, a profile change)
	// can change what ports and profiles there are. Streams come and go all
	// the time — the mixer's own meters among them — so only the set of
	// devices is watched.
	readonly property string deviceKey: root.outputs.concat(root.inputs).map(n => n.name).join("|")
	onDeviceKeyChanged: refreshSoon.restart()

	Process {
		id: probe

		command: ["sh", "-c", "pactl -f json list sinks; echo; pactl -f json list sources; echo; pactl -f json list cards"]

		stdout: StdioCollector {
			onStreamFinished: {
				const parts = this.text.split("\n").filter(l => l.trim().length > 0);
				if (parts.length < 3) return;
				try {
					const map = ({});
					for (const dev of JSON.parse(parts[0]).concat(JSON.parse(parts[1]))) {
						map[dev.name] = {
							active: dev.active_port ?? "",
							ports: (dev.ports ?? []).map(p => ({
								name: p.name, description: p.description,
								available: p.availability !== "not available"
							}))
						};
					}
					// Assigned only when something changed, so the mixer's port
					// and profile lists are not rebuilt by a refresh that found
					// everything as it was.
					if (JSON.stringify(map) !== JSON.stringify(root.ports)) root.ports = map;
					const cards = JSON.parse(parts[2]).map(c => ({
						name: c.name,
						description: c.properties?.["device.description"] ?? c.name,
						active: c.active_profile ?? "",
						profiles: Object.keys(c.profiles ?? {}).map(k => ({
							name: k, description: c.profiles[k].description ?? k,
							available: c.profiles[k].available !== false,
							priority: c.profiles[k].priority ?? 0
						})).sort((a, b) => (a.name === "off") - (b.name === "off") || b.priority - a.priority)
					}));
					if (JSON.stringify(cards) !== JSON.stringify(root.cards)) root.cards = cards;
				} catch (err) {}
			}
		}
	}

	// Pipewire exposes a sink's loopback as "<sink>.monitor", which is how a
	// recorder captures what is coming out of the speakers. It is not listed
	// as a node of its own, so the name is derived.
	readonly property string monitorName: root.sink ? root.sink.name + ".monitor" : ""
}
