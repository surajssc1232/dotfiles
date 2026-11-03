import QtQuick
import qs

// Themed surface for menu content, opaque to clicks.
Rectangle {
	radius: Config.radius
	color: Config.surface
	border.width: 1
	border.color: Config.border

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		z: -1
	}
}
