import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

// Only present while a keyd layer is held: the layer's own name, so a sticky
// toggle layer cannot be left on without something on screen saying so.
Pill {
	id: root

	visible: Keyd.active
	background: Config.bgAlt

	Label {
		text: Config.icons.keyboard
		color: Config.accent
		font.pixelSize: Config.fontSize - 2
	}

	Label {
		text: Keyd.label
		color: Config.fg
	}

	// Arriving rather than appearing: a layer going live is worth noticing,
	// and a pill that simply blinks into the bar reads as a rendering glitch.
	NumberAnimation on opacity {
		running: root.visible
		from: 0
		to: 1
		duration: 160
		easing.type: Easing.OutQuad
	}
}
