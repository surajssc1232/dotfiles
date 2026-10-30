import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// A notch hanging from the top edge for as long as a keyd layer is held. The
// bar pill says the same thing, but a fullscreen video covers the bar; this
// sits on the overlay layer, above fullscreen windows, so a sticky vim layer
// can never be left on unseen. It takes no input, so nothing under it is lost.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	// Stays mapped until the notch has finished sliding back up.
	visible: Keyd.active || notch.y > -root.implicitHeight

	anchors {
		top: true
	}

	implicitWidth: Math.max(96, row.implicitWidth + Config.padding * 3)
	implicitHeight: 30

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-layer-notch"

	mask: Region {}

	Rectangle {
		id: notch

		width: root.implicitWidth
		height: root.implicitHeight
		y: Keyd.active ? 0 : -root.implicitHeight

		color: Config.bg
		border.width: 1
		border.color: Config.border
		// Only the bottom corners are rounded: the top ones are pushed off
		// the surface by the overhang, so the notch reads as part of the edge.
		radius: Config.radius

		Behavior on y {
			NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
		}

		Rectangle {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			anchors.leftMargin: 1
			anchors.rightMargin: 1
			height: parent.radius
			color: parent.color
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

				// Last remembered name, so the text does not vanish mid-slide.
				property string shown: ""
				text: shown.toUpperCase()
				color: Config.fg
				font.bold: true

				Connections {
					target: Keyd
					function onLabelChanged() {
						if (Keyd.label.length > 0) name.shown = Keyd.label;
					}
				}

				Component.onCompleted: shown = Keyd.label
			}
		}
	}
}
