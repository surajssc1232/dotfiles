import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import qs.widgets

// Scroll to change volume, click to mute, right-click opens the mixer.
Pill {
	id: root

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var audio: sink?.audio ?? null
	readonly property int percent: audio ? Math.round(audio.volume * 100) : 0
	readonly property bool muted: audio?.muted ?? false

	interactive: true
	visible: sink !== null

	// Keeps the default sink's volume/mute properties bound and live.
	PwObjectTracker {
		objects: root.sink ? [root.sink] : []
	}

	onClicked: event => {
		if (!audio) return;
		if (event.button === Qt.RightButton) mixer.startDetached();
		else audio.muted = !audio.muted;
	}

	onWheel: event => {
		if (!audio) return;
		const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
		audio.muted = false;
		audio.volume = Math.max(0, Math.min(1, audio.volume + step));
	}

	Process {
		id: mixer
		command: ["pavucontrol"]
	}

	Label {
		text: root.muted ? Config.icons.volMute
			: root.percent > 50 ? Config.icons.volHigh
			: Config.icons.volLow
		color: root.muted ? Config.red : Config.accent
	}

	Label {
		text: root.muted ? "muted" : root.percent + "%"
		color: root.muted ? Config.fgDim : Config.fg
	}
}
