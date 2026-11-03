import QtQuick
import QtQuick.Layouts
import qs

// A rounded, hoverable container used for every bar module.
MouseArea {
	id: root

	default property alias content: layout.data
	property color background: Config.bgAlt
	property bool interactive: false

	implicitWidth: layout.implicitWidth + Config.padding * 2
	implicitHeight: Config.barHeight - 8

	hoverEnabled: true
	cursorShape: interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
	acceptedButtons: interactive ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton

	Rectangle {
		anchors.fill: parent
		radius: Config.radius
		color: root.containsMouse && root.interactive
			? Config.hover(root.background)
			: root.background

		Behavior on color {
			ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
		}
	}

	RowLayout {
		id: layout
		anchors.centerIn: parent
		spacing: Config.spacing
	}
}
