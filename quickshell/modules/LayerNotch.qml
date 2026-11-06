import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// A small card in the bottom-right corner for as long as a keyd layer is held
// or caps lock is on. It is the only layer indicator: it sits on the overlay layer, above
// fullscreen windows, so a sticky vim layer can never be left on unseen even
// under a video. It takes no input, so nothing under it is lost.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	// Layer names as the card shows them, where the raw name reads badly.
	readonly property var titles: ({ fkeys: "F1–F12" })
	readonly property var names: Keyd.layers.map(l => root.titles[l] ?? l)
		.concat(CapsLock.on ? ["caps"] : [])
	readonly property bool active: names.length > 0
	readonly property string label: names.join(" · ")

	// Stays mapped until the card has finished fading out.
	visible: root.active || card.opacity > 0

	anchors {
		bottom: true
		right: true
	}

	margins {
		bottom: 24
		right: 24
	}

	implicitWidth: Math.max(96, row.implicitWidth + Config.padding * 3)
	implicitHeight: 34

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-layer-notch"

	mask: Region {}

	Panel {
		id: card

		width: root.implicitWidth
		height: root.implicitHeight

		opacity: root.active ? 1 : 0
		y: root.active ? 0 : 8

		Behavior on opacity {
			NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
		}

		Behavior on y {
			NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
		}

		Row {
			id: row

			anchors.centerIn: parent
			spacing: 6

			Label {
				text: Config.icons.keyboard
				color: Config.accent
				font.pixelSize: Config.fontSize - 2
			}

			Label {
				id: name

				// Last remembered name, so the text does not vanish mid-fade.
				property string shown: ""
				text: shown.toUpperCase()
				color: Config.fg
				font.bold: true

				Connections {
					target: root
					function onLabelChanged() {
						if (root.label.length > 0) name.shown = root.label;
					}
				}

				Component.onCompleted: shown = root.label
			}
		}
	}
}
