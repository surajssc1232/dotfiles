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
		case "brightness": return Config.icons.brightness;
		case "layer": return Config.icons.keyboard;
		default: return "";
		}
	}

	readonly property string caption: {
		switch (root.kind) {
		case "volume": return root.muted ? "Muted" : Math.round(root.fraction * 100) + "%";
		case "mic": return root.muted ? "Mic off" : "Mic on";
		case "brightness": return Brightness.percent + "%";
		case "layer": return Keyd.label;
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

	Rectangle {
		id: card

		anchors.fill: parent
		radius: Config.radius
		color: Config.bg
		border.width: 1
		border.color: Config.border

		opacity: Osd.shown ? 1 : 0
		y: Osd.shown ? 0 : 8

		Behavior on opacity {
			NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
		}

		Behavior on y {
			NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Config.padding
			spacing: 6

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Label {
					text: root.icon
					color: root.muted ? Config.red : Config.accent
					font.pixelSize: Config.fontSize + 1
				}

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: root.caption
					color: Config.fg
					elide: Text.ElideRight
				}
			}

			// A layer has no magnitude — a bar under it would be meaningless.
			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 4

				visible: root.kind !== "layer"
				radius: 2
				color: Config.bgAlt

				Rectangle {
					width: parent.width * Math.max(0, Math.min(1, root.fraction))
					height: parent.height
					radius: parent.radius
					color: root.muted ? Config.red : Config.accent

					Behavior on width {
						NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
					}
				}
			}
		}
	}
}
