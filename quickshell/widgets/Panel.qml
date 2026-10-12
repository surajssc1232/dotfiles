import QtQuick
import qs

// Themed surface for menu content, opaque to clicks.
Rectangle {
	id: root

	// Frosted in glass mode. Over the desktop the blur is exact if the screen
	// and this panel's top-left on it are given; elsewhere it is simply a
	// blurred wallpaper, which at this blur radius is indistinguishable.
	property bool frosted: true
	property var screen
	property real screenX: 0
	property real screenY: 0

	radius: Config.radius
	color: frosted && Config.glass ? "transparent" : Config.panelSurface
	border.width: 1
	border.color: Config.border

	Frost {
		anchors.fill: parent
		visible: root.frosted && Config.glass
		screen: root.screen
		screenX: root.screenX
		screenY: root.screenY
		radius: root.radius
		z: -3
	}

	// The tint, over the frost rather than under it.
	Rectangle {
		anchors.fill: parent
		visible: root.frosted && Config.glass
		radius: root.radius
		color: Config.surface
		z: -2
	}

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		z: -1
	}
}
