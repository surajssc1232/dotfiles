import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

// Temperature beside the clock; everything else a click away.
Pill {
	id: root

	visible: Config.weather && (Weather.valid || Weather.error !== "")
	interactive: true
	onClicked: layer.open = !layer.open

	Label {
		text: Weather.error !== "" ? Config.icons.warning : Weather.icon
		color: Weather.error !== "" ? Config.fgDim : Config.accent
		font.pixelSize: Config.fontSize - 2
	}

	Label {
		text: Weather.valid ? Math.round(Weather.temperature) + "°" : "—"
		color: Config.fg
	}

	PopupLayer {
		id: layer

		anchorItem: root
		contentWidth: 640
		contentHeight: pane.implicitHeight + (Config.padding + 4) * 2

		// Focusable for as long as the panel is open rather than only while
		// the city field is up: a layer surface is mapped with its keyboard
		// mode already decided, and changing it afterwards is not something a
		// compositor is obliged to honour.
		keyboardFocus: layer.open

		Panel {
			anchors.fill: parent

			focus: true
			Keys.onEscapePressed: layer.open = false

			WeatherPanel {
				id: pane

				anchors.fill: parent
				anchors.margins: Config.padding + 4
				active: layer.open
			}
		}
	}
}
