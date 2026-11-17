import QtQuick
import qs

// A small rounded toggle or button: a tab, a port, a choice in a short list.
MouseArea {
	id: root

	property string text
	property string glyph
	property bool active: false
	property bool dim: false
	property color tone: Config.accent
	property int pad: 10

	implicitWidth: row.implicitWidth + root.pad * 2
	implicitHeight: 24
	hoverEnabled: true
	cursorShape: Qt.PointingHandCursor

	Rectangle {
		anchors.fill: parent
		radius: height / 2
		color: root.active ? Qt.alpha(root.tone, 0.22)
			: root.containsMouse ? Config.bgAlt : "transparent"
		border.width: 1
		border.color: root.active ? root.tone : Config.border

		Behavior on color { ColorAnimation { duration: Config.animFast } }
	}

	Row {
		id: row

		anchors.centerIn: parent
		spacing: 6

		Label {
			visible: root.glyph !== ""
			text: root.glyph
			color: root.active ? root.tone : Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}

		Label {
			visible: root.text !== ""
			text: root.text
			color: root.active ? root.tone : root.dim ? Qt.alpha(Config.fgDim, 0.6) : Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}
	}
}
