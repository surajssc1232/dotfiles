import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Picker for audio devices, shown under a slider tile.
Item {
	id: root

	property var devices: []
	property var current: null
	property string emptyText: "No devices"

	signal picked(var device)

	readonly property int rowHeight: 28

	implicitHeight: column.implicitHeight

	ColumnLayout {
		id: column

		anchors.fill: parent
		spacing: 0

		Label {
			Layout.fillWidth: true
			Layout.preferredHeight: root.rowHeight
			visible: root.devices.length === 0
			text: root.emptyText
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 3
			horizontalAlignment: Text.AlignHCenter
			verticalAlignment: Text.AlignVCenter
		}

		Repeater {
			model: root.devices

			MouseArea {
				id: entry

				required property var modelData
				readonly property bool active: modelData === root.current

				Layout.fillWidth: true
				Layout.preferredHeight: root.rowHeight

				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.picked(entry.modelData)

				Rectangle {
					anchors.fill: parent
					anchors.margins: 1
					radius: Config.radius - 4
					color: entry.containsMouse ? Config.bgAlt : "transparent"
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 10
					anchors.rightMargin: 10
					spacing: 8

					Label {
						text: Config.icons.swatch
						color: entry.active ? Config.accent : Config.fgDim
						font.pixelSize: Config.fontSize - 6
					}

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: Audio.label(entry.modelData)
						color: entry.active ? Config.accent : Config.fg
						font.pixelSize: Config.fontSize - 3
						elide: Text.ElideRight
					}

					Label {
						text: Config.icons.check
						color: Config.accent
						visible: entry.active
						font.pixelSize: Config.fontSize - 4
					}
				}
			}
		}
	}
}
