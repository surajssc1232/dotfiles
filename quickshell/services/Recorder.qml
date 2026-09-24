pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Screen recording, via wf-recorder.
//
// Unlike screenshots there is no in-shell equivalent — wlr-screencopy gives
// single frames, not an encoded stream — so this drives wf-recorder and simply
// owns the lifecycle, the audio routing and what happens to the file after.
Singleton {
	id: root

	// "none" | "system" | "mic" | "auto"
	//
	// auto follows what is plugged in: a headset's microphone if one is
	// connected, silence otherwise. That is the behaviour you want by default
	// — recording the laptop's built-in mic unasked is rarely wanted.
	// Restored in Component.onCompleted rather than as an initialiser: reading
	// the store in a binding makes writing back to it a binding loop.
	property string audioMode: "auto"
	onAudioModeChanged: Persist.set("recorderAudio", root.audioMode)

	property bool recording: false
	property bool finishing: false
	property int elapsed: 0
	property string pendingPath: ""

	readonly property string directory: Quickshell.env("HOME") + "/Videos/Recordings"

	signal finished(string path)
	signal failed(string reason)

	// What `auto` actually resolves to right now, for display.
	readonly property string effectiveMode: {
		if (root.audioMode !== "auto") return root.audioMode;
		return Audio.headsetConnected ? "mic" : "none";
	}

	readonly property string audioLabel: {
		switch (root.effectiveMode) {
		case "system": return "System audio";
		case "mic": return Audio.label(root.micDevice);
		default: return "No audio";
		}
	}

	// In auto the headset mic is used explicitly; chosen manually, whatever is
	// currently the default input applies.
	readonly property var micDevice: root.audioMode === "auto"
		? Audio.headsetMic
		: (Audio.source ?? Audio.headsetMic)

	function timestamp(): string {
		const d = new Date();
		const p = n => (n < 10 ? "0" : "") + n;
		return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
			+ "_" + p(d.getHours()) + "-" + p(d.getMinutes()) + "-" + p(d.getSeconds());
	}

	function clock(): string {
		const m = Math.floor(root.elapsed / 60);
		const s = root.elapsed % 60;
		return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
	}

	// `geometry` is "x,y WxH", or empty for the whole output.
	function start(geometry: string) {
		if (root.recording || root.finishing) return;

		const path = root.directory + "/Recording_" + root.timestamp() + ".mp4";
		const args = ["wf-recorder", "-f", path];

		if (geometry) {
			args.push("-g");
			args.push(geometry);
		}

		const mode = root.effectiveMode;
		if (mode === "system" && Audio.monitorName) {
			args.push("--audio=" + Audio.monitorName);
		} else if (mode === "mic" && root.micDevice) {
			args.push("--audio=" + root.micDevice.name);
		}

		root.pendingPath = path;
		root.elapsed = 0;
		recorder.command = args;
		recorder.running = true;
		root.recording = true;
	}

	function stop() {
		if (!root.recording) return;
		root.finishing = true;
		// wf-recorder finalises the container on SIGINT. Killing it outright
		// leaves an unplayable file with no moov atom.
		recorder.signal(2);
	}

	function cancel() {
		if (!root.recording) return;
		root.discardOnExit = true;
		root.stop();
	}

	property bool discardOnExit: false

	Process {
		id: recorder

		stderr: StdioCollector {}

		onExited: (code, status) => {
			const path = root.pendingPath;
			root.recording = false;
			root.finishing = false;
			root.pendingPath = "";

			if (root.discardOnExit) {
				root.discardOnExit = false;
				remover.command = ["rm", "-f", path];
				remover.running = true;
				return;
			}

			// SIGINT is the normal way this ends, so a non-zero code alone is
			// not a failure; the file existing is what matters.
			checker.command = ["sh", "-c",
				'[ -s "$1" ] && echo ok || echo missing', "sh", path];
			checker.pendingPath = path;
			checker.running = true;
		}
	}

	Process {
		id: checker

		property string pendingPath: ""

		stdout: StdioCollector {
			onStreamFinished: {
				if (text.trim() === "ok") root.finished(checker.pendingPath);
				else root.failed("wf-recorder produced no file");
			}
		}
	}

	Process { id: remover }
	Process { id: mkdir }
	Process { id: clip }
	Process { id: notify }

	Timer {
		interval: 1000
		repeat: true
		running: root.recording
		onTriggered: root.elapsed++
	}

	// ---- what happens to the file afterwards ----
	function keep(path: string) {
		notify.command = ["notify-send", "-a", "Recorder", "-i", "camera-video",
			"Recording saved", path.split("/").pop()];
		notify.running = true;
	}

	function copy(path: string) {
		// Copied as a file reference rather than raw bytes: that is what file
		// managers and chat clients actually accept on paste, and a video is
		// far too large to hand over as an inline blob.
		clip.command = ["sh", "-c",
			'printf "file://%s\\r\\n" "$1" | wl-copy --type text/uri-list', "sh", path];
		clip.running = true;

		notify.command = ["notify-send", "-a", "Recorder", "-i", "camera-video",
			"Recording copied", "Paste to attach " + path.split("/").pop()];
		notify.running = true;
	}

	function discard(path: string) {
		remover.command = ["rm", "-f", path];
		remover.running = true;
	}

	IpcHandler {
		target: "recorder"

		function start(): void {
			root.start("");
		}

		function stop(): void {
			root.stop();
		}

		function toggle(): void {
			if (root.recording) root.stop();
			else root.start("");
		}

		function cancel(): void {
			root.cancel();
		}
	}

	Component.onCompleted: {
		root.audioMode = Persist.get("recorderAudio", "auto");
		mkdir.command = ["mkdir", "-p", root.directory];
		mkdir.running = true;
	}
}
