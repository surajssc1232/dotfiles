import QtQuick
import Quickshell
import qs
import qs.widgets

Pill {
	id: root

	readonly property date now: clock.date

	interactive: true
	onClicked: {
		if (!layer.open) calendar.monthOffset = 0;
		layer.open = !layer.open;
	}

	PopupLayer {
		id: layer

		anchorItem: root
		contentWidth: calendar.implicitWidth
		contentHeight: calendar.implicitHeight

		Calendar {
			id: calendar

			anchors.fill: parent
			today: root.now
		}
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}

	Label {
		text: Qt.formatDateTime(root.now, Config.clockFormat)
	}

	Label {
		text: Config.icons.calendar
		color: Config.fgDim
		font.pixelSize: Config.fontSize - 1
	}

	Label {
		text: Qt.formatDateTime(root.now, Config.dateFormat)
		color: Config.fgDim
	}
}
