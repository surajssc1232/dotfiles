import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

// Bell in the bar: unread count, and the session's notification history.
Pill {
	id: root

	readonly property int listWidth: 380
	readonly property int listHeight: 420

	interactive: true
	onClicked: layer.open = !layer.open

	// PopupLayer closes itself on a click outside, so `open` stays the one
	// source of truth and the keybind flips it rather than driving a binding.
	Connections {
		target: Notifs

		function onCenterToggled(): void {
			layer.open = !layer.open;
		}

		function onCenterClosed(): void {
			layer.open = false;
		}
	}

	Label {
		text: Notifs.dnd ? Config.icons.bellOff : Config.icons.bell
		color: Notifs.dnd ? Config.fgDim
			: Notifs.count > 0 ? Config.accent : Config.fg
	}

	Label {
		text: Notifs.count
		color: Config.fgDim
		visible: Notifs.count > 0
	}

	PopupLayer {
		id: layer

		anchorItem: root
		contentWidth: root.listWidth
		contentHeight: root.listHeight

		Panel {
			anchors.fill: parent

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: Config.padding
				spacing: 0

				// ---- header ----
				RowLayout {
					Layout.fillWidth: true
					Layout.preferredHeight: 22
					spacing: 6

					Label {
						Layout.fillWidth: true
						text: "Notifications"
						color: Config.accent
					}

					HeaderButton {
						icon: Notifs.dnd ? Config.icons.bellOff : Config.icons.bell
						active: Notifs.dnd
						onTriggered: Notifs.toggleDnd()
					}

					HeaderButton {
						icon: Config.icons.broom
						enabled: Notifs.count > 0
						onTriggered: Notifs.clearAll()
					}
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 1
					Layout.topMargin: 4
					Layout.bottomMargin: 4
					color: Config.border
				}

				// ---- empty state ----
				ColumnLayout {
					Layout.fillWidth: true
					Layout.fillHeight: true
					visible: Notifs.count === 0
					spacing: 6

					Item { Layout.fillHeight: true }

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: Config.icons.inbox
						color: Config.fgDim
						font.pixelSize: Config.fontSize + 10
					}

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: Notifs.dnd ? "Do not disturb is on" : "Nothing to catch up on"
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 1
					}

					Item { Layout.fillHeight: true }
				}

				// ---- history ----
				ListView {
					Layout.fillWidth: true
					Layout.fillHeight: true

					visible: Notifs.count > 0
					model: Notifs.entries
					spacing: Config.spacing
					clip: true
					boundsBehavior: Flickable.StopAtBounds

					delegate: NotificationCard {
						required property var modelData

						width: ListView.view.width
						notif: modelData
						onClosed: Notifs.dismiss(modelData)
					}
				}
			}
		}
	}

	// Small icon button in the panel header.
	component HeaderButton: MouseArea {
		id: button

		property string icon
		property bool active: false
		signal triggered()

		implicitWidth: 24
		implicitHeight: 22

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		opacity: enabled ? 1 : 0.4
		onClicked: if (enabled) triggered()

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: button.active || button.containsMouse ? Config.bgAlt : "transparent"
		}

		Label {
			anchors.centerIn: parent
			text: button.icon
			font.pixelSize: Config.fontSize - 2
			color: button.active ? Config.accent
				: button.containsMouse ? Config.accent : Config.fgDim
		}
	}
}
