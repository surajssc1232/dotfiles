import QtQuick
import qs

Text {
	color: Config.fg
	font.family: Config.font
	font.pixelSize: Config.fontSize
	verticalAlignment: Text.AlignVCenter

	// Cross-fades on a theme switch instead of snapping.
	Behavior on color {
		ColorAnimation { duration: Config.themeFade }
	}
}
