import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

// One notification, used by both the toast stack and the history list.
//
// A header line names the app and when it arrived; under it the icon or
// picture, the summary in bold and the body. A wide picture (a screenshot, a
// thumbnail) is shown across the card's full width rather than squeezed into
// the icon's square, where it would show nothing.
Rectangle {
	id: root

	required property var notif
	property bool showActions: true

	// Time left before a toast goes, 1 down to 0; below 0 shows no bar, as in
	// the history list.
	property real progress: -1

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

	readonly property bool critical: notif.urgency === NotificationUrgency.Critical
	readonly property color urgencyColor: root.critical ? Config.red
		: notif.urgency === NotificationUrgency.Low ? Config.fgDim : Config.accent

	readonly property string iconSource: root.notif.appIcon !== ""
		? Quickshell.iconPath(root.notif.appIcon, true) : ""

	// The picture, if any. One named after a theme icon is looked up first,
	// so an icon the theme lacks shows nothing rather than the checkerboard
	// Qt draws for a missing image.
	readonly property string pictureSource: {
		const image = root.notif.image ?? "";
		if (!image.startsWith("image://icon/")) return image;
		const name = image.substring("image://icon/".length);
		// An image-path hint holding a file arrives wrapped the same way;
		// that is a picture to load, not an icon to look up.
		if (name.startsWith("/")) return "file://" + name;
		if (name.startsWith("file://")) return name;
		return Quickshell.iconPath(name, true);
	}

	// Wide once loaded: shown as a banner instead of in the icon's square.
	readonly property bool wideImage: picture.status === Image.Ready
		&& picture.implicitWidth > picture.implicitHeight * 1.25

	readonly property bool hovered: body.containsMouse

	implicitHeight: layout.implicitHeight + Config.padding * 2

	radius: Config.radius
	color: root.critical ? Qt.tint(Config.bg, Qt.rgba(Config.red.r, Config.red.g, Config.red.b, 0.08))
		: root.hovered ? Qt.tint(Config.bg, Qt.rgba(Config.fg.r, Config.fg.g, Config.fg.b, 0.03))
		: Config.bg
	border.width: root.critical ? 1.5 : 1
	border.color: root.critical ? Config.red
		: root.hovered ? Qt.alpha(Config.accent, 0.6) : Config.border

	Behavior on border.color { ColorAnimation { duration: 140 } }
	Behavior on color { ColorAnimation { duration: 140 } }

	// Behind everything, so the action buttons and the close button still take
	// their own clicks. With no default action there is nothing to activate,
	// and dismissing is the only sensible thing a click can mean.
	MouseArea {
		id: body

		anchors.fill: parent
		z: -1

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			root.defaultAction?.invoke();
			root.closed();
		}
	}

	ColumnLayout {
		id: layout

		anchors.left: parent.left
		anchors.right: parent.right
		anchors.top: parent.top
		anchors.margins: Config.padding
		spacing: 8

		// ---- app, time, close ----
		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			IconImage {
				Layout.preferredWidth: 14
				Layout.preferredHeight: 14
				source: root.iconSource
				visible: root.iconSource !== ""
			}

			// Urgency, as a dot, where there is no icon to sit beside.
			Rectangle {
				Layout.preferredWidth: 6
				Layout.preferredHeight: 6
				radius: 3
				color: root.urgencyColor
				visible: root.iconSource === ""
			}

			Label {
				Layout.minimumWidth: 0
				Layout.maximumWidth: root.width * 0.55
				text: (root.notif.appName || "Notification").toUpperCase()
				color: root.critical ? Config.red : Config.fgDim
				font.pixelSize: Config.fontSize - 4
				font.letterSpacing: 1
				font.weight: Font.DemiBold
				elide: Text.ElideRight
			}

			Label {
				text: "· " + Notifs.ago(root.notif)
				color: Config.fgDim
				opacity: 0.8
				font.pixelSize: Config.fontSize - 4
				visible: Notifs.ago(root.notif) !== ""
			}

			Label {
				text: "· urgent"
				color: Config.red
				font.pixelSize: Config.fontSize - 4
				visible: root.critical
			}

			Item { Layout.fillWidth: true }

			MouseArea {
				id: closeButton

				Layout.preferredWidth: 20
				Layout.preferredHeight: 20

				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.closed()

				// Fades up with the card's hover; always there to click.
				opacity: root.hovered || containsMouse ? 1 : 0.5
				Behavior on opacity { NumberAnimation { duration: 140 } }

				Rectangle {
					anchors.fill: parent
					radius: 10
					color: closeButton.containsMouse ? Config.red : Config.bgAlt
				}

				Label {
					anchors.centerIn: parent
					text: Config.icons.kill
					font.pixelSize: Config.fontSize - 5
					color: closeButton.containsMouse ? Config.bg : Config.fgDim
				}
			}
		}

		// ---- icon or picture, and the message ----
		RowLayout {
			Layout.fillWidth: true
			spacing: 12

			Rectangle {
				Layout.preferredWidth: 44
				Layout.preferredHeight: 44
				Layout.alignment: Qt.AlignTop

				// A square picture here; a wide one goes under the text, and
				// with neither the app's icon stands in, larger.
				visible: !root.wideImage && (picture.status === Image.Ready || root.iconSource !== "")
				radius: Config.radius - 2
				color: Config.bgAlt
				clip: true

				Image {
					anchors.fill: parent
					source: root.wideImage ? "" : root.pictureSource
					fillMode: Image.PreserveAspectCrop
					asynchronous: true
					sourceSize.width: 88
					sourceSize.height: 88
					visible: status === Image.Ready
				}

				IconImage {
					anchors.centerIn: parent
					implicitSize: 28
					source: root.iconSource
					visible: picture.status !== Image.Ready && root.iconSource !== ""
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				Layout.alignment: Qt.AlignTop
				spacing: 3

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: root.notif.summary
					font.pixelSize: Config.fontSize + 1
					font.weight: Font.DemiBold
					wrapMode: Text.WordWrap
					maximumLineCount: 2
					elide: Text.ElideRight
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
					lineHeight: 1.1
				}
			}
		}

		// ---- a wide picture, across the card ----
		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: root.wideImage
				? Math.min(160, width * picture.implicitHeight / Math.max(1, picture.implicitWidth))
				: 0
			visible: root.wideImage
			radius: Config.radius - 4
			color: Config.bgAlt
			clip: true

			// Loaded here whatever its shape, so its size can be read; the
			// square slot above shows its own copy when it is not wide.
			Image {
				id: picture

				anchors.fill: parent
				anchors.margins: 1
				source: root.pictureSource
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				sourceSize.width: 720
			}
		}

		// ---- actions the sending app offered ----
		RowLayout {
			Layout.fillWidth: true
			spacing: 6
			visible: root.showActions && root.otherActions.length > 0

			Repeater {
				model: root.otherActions

				MouseArea {
					id: action

					required property var modelData

					Layout.fillWidth: true
					implicitWidth: actionLabel.implicitWidth + 20
					implicitHeight: 28

					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						modelData.invoke();
						root.closed();
					}

					Rectangle {
						anchors.fill: parent
						radius: Config.radius - 4
						color: action.containsMouse ? Config.accent : Config.bgAlt

						Behavior on color { ColorAnimation { duration: 120 } }
					}

					Label {
						id: actionLabel

						anchors.centerIn: parent
						width: Math.min(implicitWidth, action.width - 12)
						text: action.modelData.text
						font.pixelSize: Config.fontSize - 2
						font.weight: Font.DemiBold
						color: action.containsMouse ? Config.bg : Config.fg
						elide: Text.ElideRight
					}
				}
			}
		}
	}

	// ---- time left on a toast ----
	Rectangle {
		anchors.left: parent.left
		anchors.bottom: parent.bottom
		anchors.leftMargin: Config.radius
		anchors.bottomMargin: 3
		width: (parent.width - Config.radius * 2) * Math.max(0, root.progress)
		height: 2
		radius: 1
		color: root.urgencyColor
		opacity: 0.7
		visible: root.progress >= 0
	}
}
