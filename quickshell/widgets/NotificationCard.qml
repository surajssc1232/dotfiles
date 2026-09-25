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

	// The "default" action is what a notification means by "clicking me does
	// the obvious thing" — opening the chat, focusing the download. Most apps
	// label it "Activate", and showing that as a button next to the others is
	// noise: the whole card is the button. So it is pulled out of the row and
	// wired to the card body instead.
	// Restored notifications carry no actions at all, hence the fallbacks.
	readonly property var allActions: notif.actions ?? []
	readonly property var defaultAction:
		root.allActions.find(a => a.identifier === "default") ?? null
	readonly property var otherActions:
		root.allActions.filter(a => a.identifier !== "default")

	readonly property color urgencyColor: notif.urgency === NotificationUrgency.Critical
		? Config.red
		: notif.urgency === NotificationUrgency.Low ? Config.fgDim : Config.accent

	implicitHeight: layout.implicitHeight + Config.padding * 2

	radius: Config.radius
	color: Config.bg
	border.width: 1
	border.color: notif.urgency === NotificationUrgency.Critical ? Config.red : Config.border

	// Behind everything, so the action buttons and the close button still take
	// their own clicks. With no default action there is nothing to activate,
	// and dismissing is the only sensible thing a click can mean.
	MouseArea {
		anchors.fill: parent
		z: -1

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			root.defaultAction?.invoke();
			root.closed();
		}
	}

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

		// A notification carrying an image is usually showing you something —
		// a screenshot, a track's artwork — and 28 pixels of it shows nothing.
		Rectangle {
			Layout.preferredWidth: 92
			Layout.preferredHeight: 58
			Layout.alignment: Qt.AlignVCenter

			visible: root.notif.image !== ""
			radius: Config.radius - 4
			color: Config.bgAlt
			clip: true

			Image {
				anchors.fill: parent
				anchors.margins: 1
				source: root.notif.image
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				sourceSize.width: 184
				sourceSize.height: 116
			}
		}

		// Otherwise the sending application's icon.
		IconImage {
			Layout.preferredWidth: 28
			Layout.preferredHeight: 28
			Layout.alignment: Qt.AlignTop

			source: root.notif.appIcon !== ""
				? Quickshell.iconPath(root.notif.appIcon, true) : ""
			visible: source !== "" && root.notif.image === ""
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
				visible: root.showActions && root.otherActions.length > 0

				Repeater {
					model: root.otherActions

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
