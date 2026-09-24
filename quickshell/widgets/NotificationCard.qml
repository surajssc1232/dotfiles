import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

// One notification, used by both the toast stack and the history list.
Rectangle {
	id: root

	required property var notif
	property bool showActions: true
	signal closed()

	readonly property color urgencyColor: notif.urgency === NotificationUrgency.Critical
		? Config.red
		: notif.urgency === NotificationUrgency.Low ? Config.fgDim : Config.accent

	implicitHeight: layout.implicitHeight + Config.padding * 2

	radius: Config.radius
	color: Config.bg
	border.width: 1
	border.color: notif.urgency === NotificationUrgency.Critical ? Config.red : Config.border

	// Urgency stripe down the leading edge.
	Rectangle {
		width: 3
		height: parent.height - Config.padding * 2
		anchors.left: parent.left
		anchors.leftMargin: 1
		anchors.verticalCenter: parent.verticalCenter
		radius: 2
		color: root.urgencyColor
	}

	RowLayout {
		id: layout

		anchors.fill: parent
		anchors.margins: Config.padding
		anchors.leftMargin: Config.padding + 4
		spacing: 8

		// App image if the notification carries one, else its icon.
		IconImage {
			Layout.preferredWidth: 28
			Layout.preferredHeight: 28
			Layout.alignment: Qt.AlignTop

			source: root.notif.image !== "" ? root.notif.image
				: root.notif.appIcon !== "" ? Quickshell.iconPath(root.notif.appIcon, true)
				: ""
			visible: source !== ""
		}

		ColumnLayout {
			Layout.fillWidth: true
			spacing: 2

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: root.notif.summary
					elide: Text.ElideRight
				}

				Label {
					text: root.notif.appName
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}
			}

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: root.notif.body
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 1
				visible: text !== ""
				wrapMode: Text.WordWrap
				maximumLineCount: 4
				elide: Text.ElideRight
				textFormat: Text.PlainText
			}

			// Actions the sending app offered.
			RowLayout {
				Layout.topMargin: 4
				spacing: 6
				visible: root.showActions && root.notif.actions.length > 0

				Repeater {
					model: root.notif.actions

					MouseArea {
						id: action

						required property var modelData

						implicitWidth: actionLabel.implicitWidth + 16
						implicitHeight: 22

						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							modelData.invoke();
							root.closed();
						}

						Rectangle {
							anchors.fill: parent
							radius: Config.radius - 4
							color: action.containsMouse ? Config.bgAlt : "transparent"
							border.width: 1
							border.color: Config.border
						}

						Label {
							id: actionLabel

							anchors.centerIn: parent
							text: action.modelData.text
							font.pixelSize: Config.fontSize - 2
							color: action.containsMouse ? Config.accent : Config.fg
						}
					}
				}
			}
		}

		// Close button.
		MouseArea {
			id: closeButton

			Layout.preferredWidth: 18
			Layout.preferredHeight: 18
			Layout.alignment: Qt.AlignTop

			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.closed()

			Rectangle {
				anchors.fill: parent
				radius: 4
				color: closeButton.containsMouse ? Config.red : "transparent"
			}

			Label {
				anchors.centerIn: parent
				text: Config.icons.kill
				font.pixelSize: Config.fontSize - 3
				color: closeButton.containsMouse ? Config.bg : Config.fgDim
			}
		}
	}
}
