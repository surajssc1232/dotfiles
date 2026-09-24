import QtQuick
import QtQuick.Layouts
import qs
import qs.widgets

// Colorscheme picker, shown as the theme tile's detail pane.
Item {
	id: root

	property bool active: false

	readonly property int entryHeight: 30
	readonly property int columns: 2
	readonly property int rows: Math.ceil(Themes.list.length / columns)

	implicitHeight: grid.implicitHeight

	GridLayout {
		id: grid

		anchors.fill: parent
		columns: root.columns
		rowSpacing: 2
		columnSpacing: 2

		Repeater {
			model: Themes.list

			MouseArea {
				id: entry

				required property var modelData
				readonly property bool current: modelData.id === Config.themeId

				Layout.fillWidth: true
				Layout.preferredHeight: root.entryHeight

				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: Config.setTheme(modelData.id)

				Rectangle {
					anchors.fill: parent
					radius: Config.radius - 4
					color: entry.containsMouse ? Config.bgAlt : "transparent"
					border.width: entry.current ? 1 : 0
					border.color: Config.accent
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 8
					anchors.rightMargin: 8
					spacing: 8

					// Each entry previews itself in its own colors.
					Rectangle {
						Layout.preferredWidth: 14
						Layout.preferredHeight: 14

						radius: 4
						color: entry.modelData.bg
						border.width: 1
						border.color: entry.modelData.border

						Rectangle {
							anchors.centerIn: parent
							width: 7
							height: 7
							radius: 4
							color: entry.modelData.accent
						}
					}

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: entry.modelData.name
						font.pixelSize: Config.fontSize - 2
						elide: Text.ElideRight
						color: entry.current ? Config.accent : Config.fg
					}

					Label {
						text: Config.icons.check
						color: Config.accent
						visible: entry.current
						font.pixelSize: Config.fontSize - 4
					}
				}
			}
		}
	}
}
