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
					Layout.preferredHeight: 26
					spacing: 8

					Label {
						text: "Notifications"
						font.pixelSize: Config.fontSize + 1
						font.weight: Font.DemiBold
					}

					// How many, as a badge beside the title.
					Rectangle {
						Layout.preferredWidth: Math.max(20, countLabel.implicitWidth + 12)
						Layout.preferredHeight: 18
						radius: 9
						color: Config.accent
						visible: Notifs.count > 0

						Label {
							id: countLabel

							anchors.centerIn: parent
							text: Notifs.count
							color: Config.bg
							font.pixelSize: Config.fontSize - 4
							font.weight: Font.Bold
						}
					}

					Label {
						Layout.fillWidth: true
						text: Notifs.dnd ? "· Silenced" : ""
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
					}

					HeaderButton {
						icon: Notifs.dnd ? Config.icons.bellOff : Config.icons.bell
						active: Notifs.dnd
						onTriggered: Notifs.toggleDnd()
					}

					HeaderButton {
						icon: Config.icons.broom
						label: "Clear"
						enabled: Notifs.count > 0
						onTriggered: Notifs.clearAll()
					}
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 1
					Layout.topMargin: 8
					Layout.bottomMargin: 10
					color: Config.border
				}

				// ---- empty state ----
				Item {
					Layout.fillWidth: true
					Layout.fillHeight: true
					visible: Notifs.count === 0

					Column {
						anchors.centerIn: parent
						spacing: 6

						Rectangle {
							anchors.horizontalCenter: parent.horizontalCenter
							width: 64
							height: 64
							radius: 32
							color: Config.bgAlt

							Label {
								anchors.centerIn: parent
								text: Notifs.dnd ? Config.icons.bellOff : Config.icons.inbox
								color: Notifs.dnd ? Config.fgDim : Config.accent
								font.pixelSize: Config.fontSize + 12
							}
						}

						Item { width: 1; height: 6 }

						Label {
							anchors.horizontalCenter: parent.horizontalCenter
							text: Notifs.dnd ? "Do not disturb is on" : "All caught up"
							font.pixelSize: Config.fontSize + 1
							font.weight: Font.DemiBold
						}

						Label {
							anchors.horizontalCenter: parent.horizontalCenter
							text: Notifs.dnd ? "New notifications wait here quietly"
								: "New notifications will show up here"
							color: Config.fgDim
							font.pixelSize: Config.fontSize - 3
						}
					}
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
		property string label
		property bool active: false
		signal triggered()

		implicitWidth: row.implicitWidth + (button.label ? 16 : 10)
		implicitHeight: 24

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		opacity: enabled ? 1 : 0.4
		onClicked: if (enabled) triggered()

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: button.active || button.containsMouse ? Config.bgAlt : "transparent"
		}

		Row {
			id: row

			anchors.centerIn: parent
			spacing: 6

			Label {
				text: button.icon
				font.pixelSize: Config.fontSize - 2
				color: button.active ? Config.accent
					: button.containsMouse ? Config.accent : Config.fgDim
			}

			Label {
				visible: button.label !== ""
				text: button.label
				font.pixelSize: Config.fontSize - 3
				color: button.containsMouse ? Config.accent : Config.fgDim
			}
		}
	}
}
