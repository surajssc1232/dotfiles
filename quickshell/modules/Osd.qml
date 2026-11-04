import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Floats above everything, near the bottom of the screen, and takes no input:
// it is a readout, and anything it covered would otherwise become unclickable.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	visible: Osd.shown

	readonly property var sinkAudio: Audio.sink?.audio ?? null
	readonly property var sourceAudio: Audio.source?.audio ?? null

	readonly property bool muted: root.kind === "volume"
		? (root.sinkAudio?.muted ?? false)
		: (root.sourceAudio?.muted ?? false)

	readonly property string kind: Osd.kind

	readonly property real fraction: {
		switch (root.kind) {
		case "volume": return root.muted ? 0 : (root.sinkAudio?.volume ?? 0);
		case "brightness": return Brightness.percent / 100;
		case "monitor": return MonitorBrightness.percent / 100;
		case "mic": return root.muted ? 0 : 1;
		default: return 0;
		}
	}

	readonly property string icon: {
		switch (root.kind) {
		case "volume":
			if (root.muted) return Config.icons.volMute;
			return root.fraction > 0.5 ? Config.icons.volHigh : Config.icons.volLow;
		case "mic": return root.muted ? Config.icons.micOff : Config.icons.mic;
		case "brightness":
		case "monitor": return Config.icons.brightness;
		default: return "";
		}
	}

	readonly property string caption: {
		switch (root.kind) {
		case "volume": return root.muted ? "Muted" : Math.round(root.fraction * 100) + "%";
		case "mic": return root.muted ? "Mic off" : "Mic on";
		case "brightness": return Brightness.percent + "%";
		case "monitor": return MonitorBrightness.percent + "%";
		default: return "";
		}
	}

	anchors {
		bottom: true
	}

	margins {
		bottom: 90
	}

	implicitWidth: 240
	implicitHeight: 62

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay

	// Nothing here is clickable, so the whole surface stays out of the way.
	mask: Region {}

	Panel {
		id: card

		anchors.fill: parent

		opacity: Osd.shown ? 1 : 0
		y: Osd.shown ? 0 : 8

		Behavior on opacity {
			NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
		}

		Behavior on y {
			NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
		}

		// The control centre's slider, so a volume change looks the same whether
		// it was dragged there or pressed on a key. The surface takes no input.
		SliderTile {
			anchors.fill: parent
			anchors.margins: 8

			icon: root.icon
			label: root.kind === "volume" ? "Volume"
				: root.kind === "mic" ? "Microphone"
				: root.kind === "brightness" ? "Brightness"
				: root.kind === "monitor" ? "Monitor" : ""
			readout: root.caption
			value: root.fraction
			dimmed: root.muted
		}
	}
}
