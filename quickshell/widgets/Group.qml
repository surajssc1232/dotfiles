import QtQuick
import QtQuick.Layouts
import qs

// A card that groups related controls, so a panel reads as a few things rather
// than a long list split up by rules. A panel holds groups, a group holds tiles.
Rectangle {
	id: root

	default property alias content: body.data
	property int pad: 8
	property int spacing: 8

	// Names the group. Part of the card rather than a label floating above it,
	// so the name lines up with the controls it is naming.
	property string title

	Layout.fillWidth: true
	implicitHeight: body.implicitHeight + root.pad * 2
	radius: Config.radius
	color: Config.surfaceGroup

	Behavior on color {
		ColorAnimation { duration: Config.themeFade }
	}

	ColumnLayout {
		id: body

		anchors.fill: parent
		anchors.margins: root.pad
		spacing: root.spacing

		Label {
			Layout.fillWidth: true
			Layout.leftMargin: 6
			Layout.topMargin: 2
			visible: root.title !== ""
			text: root.title
			color: Config.accent
			font.pixelSize: Config.fontSize - 2
		}
	}
}
