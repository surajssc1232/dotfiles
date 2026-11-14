import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

// niri workspaces on this bar's monitor, each drawn with the icons of the
// apps open on it. Click a workspace to go there, click an icon to jump
// straight to that window.
Pill {
	id: root

	readonly property string output: root.QsWindow.window?.screen?.name ?? ""
	readonly property var list: Niri.on(root.output)

	visible: Niri.available && root.list.length > 0

	Repeater {
		model: root.list

		Rectangle {
			id: chip

			required property var modelData
			readonly property var ws: chip.modelData

			Layout.preferredHeight: Config.barHeight - 14
			Layout.preferredWidth: row.implicitWidth + 12
			radius: Config.radius - 3
			color: chip.ws.active ? Qt.alpha(Config.accent, 0.28)
				: hover.hovered ? Config.hover(Config.bgAlt) : "transparent"
			border.width: chip.ws.urgent ? 1 : 0
			border.color: Config.red

			Behavior on color {
				ColorAnimation { duration: Config.animFast }
			}
			Behavior on Layout.preferredWidth {
				NumberAnimation { duration: Config.animMed; easing.type: Easing.OutCubic }
			}

			HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
			TapHandler { onTapped: Niri.focus(chip.ws) }

			Row {
				id: row

				anchors.centerIn: parent
				spacing: 4

				Label {
					anchors.verticalCenter: parent.verticalCenter
					text: chip.ws.name || chip.ws.idx
					color: chip.ws.active ? Config.accent : Config.fgDim
					font.bold: chip.ws.active
					font.pixelSize: Config.fontSize - 1
				}

				Repeater {
					// Capped so a busy workspace does not swallow the bar.
					model: chip.ws.windows.slice(0, 5)

					Item {
						id: app

						required property var modelData
						readonly property string icon:
							Quickshell.iconPath(app.modelData.app_id ?? "", true)

						anchors.verticalCenter: parent.verticalCenter
						width: 16
						height: 16
						opacity: app.modelData.is_focused || chip.ws.active ? 1 : 0.6

						IconImage {
							anchors.fill: parent
							source: app.icon
							visible: app.icon !== ""
						}

						// No icon in the theme: the app's first letter instead.
						Label {
							anchors.centerIn: parent
							visible: app.icon === ""
							text: (app.modelData.app_id || "?").charAt(0).toUpperCase()
							font.pixelSize: Config.fontSize - 2
							font.bold: true
							color: Config.fg
						}

						Rectangle {
							anchors.horizontalCenter: parent.horizontalCenter
							anchors.top: parent.bottom
							anchors.topMargin: 1
							width: 4; height: 2; radius: 1
							color: Config.accent
							visible: app.modelData.is_focused
						}

						TapHandler { onTapped: Niri.focusWindow(app.modelData.id) }
					}
				}

				Label {
					anchors.verticalCenter: parent.verticalCenter
					visible: chip.ws.windows.length > 5
					text: "+" + (chip.ws.windows.length - 5)
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}
			}
		}
	}
}
