import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Toast stack under the right end of the bar.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	visible: Notifs.popups.length > 0

	anchors {
		top: true
		right: true
	}

	margins {
		top: Config.barMargin * 2 + Config.barHeight
		right: Config.barMargin
	}

	implicitWidth: 380
	implicitHeight: Math.max(1, column.implicitHeight)

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay

	// Only the cards take clicks; the gaps between them stay click-through
	// so the toast stack never swallows input meant for the window below.
	mask: Region {
		item: column
	}

	ColumnLayout {
		id: column

		width: parent.width
		spacing: Config.spacing

		Repeater {
			model: Notifs.popups

			NotificationCard {
				id: card

				required property var modelData

				Layout.fillWidth: true

				notif: modelData
				onClosed: Notifs.dismiss(modelData)

				// Hovering holds the toast open, so it cannot vanish out from
				// under the pointer on the way to a button.
				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.NoButton
					hoverEnabled: true
					z: -1
					onEntered: life.stop()
					onExited: if (life.interval > 0) life.restart()
				}

				Timer {
					id: life

					interval: Notifs.timeoutFor(card.modelData)
					running: interval > 0
					onTriggered: Notifs.hidePopup(card.modelData)
				}

				// Slides in from the right.
				NumberAnimation on x {
					from: root.width
					to: 0
					duration: 180
					easing.type: Easing.OutCubic
				}
			}
		}
	}
}
