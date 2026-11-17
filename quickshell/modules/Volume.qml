import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services
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
		if (event.button === Qt.RightButton) layer.open = !layer.open;
		else audio.muted = !audio.muted;
	}

	onWheel: event => {
		if (!audio) return;
		const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
		// Settings can push the sink past 100%. Scrolling up here must not snap
		// it back down, or asking for "louder" would make it quieter.
		if (step > 0 && audio.volume >= 1) return;
		audio.muted = false;
		audio.volume = Math.max(0, Math.min(1, audio.volume + step));
	}

	// Over IPC, only the bar on the first screen answers, so one mixer opens.
	Connections {
		target: Audio
		function onMixerToggleRequested() {
			if (root.QsWindow.window?.screen === Quickshell.screens[0]) layer.open = !layer.open;
		}
	}

	// The mixer: apps, devices, ports, profiles. See modules/AudioMixer.qml.
	PopupLayer {
		id: layer

		anchorItem: root
		keyboardFocus: true
		contentWidth: mixer.implicitWidth + Config.inset * 2
		contentHeight: mixer.implicitHeight + Config.inset * 2

		Panel {
			anchors.fill: parent

			AudioMixer {
				id: mixer

				anchors.fill: parent
				anchors.margins: Config.inset
				live: layer.open
			}
		}
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
