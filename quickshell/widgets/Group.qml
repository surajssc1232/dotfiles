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

	Layout.fillWidth: true
	implicitHeight: body.implicitHeight + root.pad * 2
	radius: Config.radius
	color: Config.surfaceGroup

	ColumnLayout {
		id: body

		anchors.fill: parent
		anchors.margins: root.pad
		spacing: root.spacing
	}
}
