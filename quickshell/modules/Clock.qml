import QtQuick
import Quickshell
import qs
import qs.widgets

Pill {
	id: root

	readonly property date now: clock.date

	interactive: true
	onClicked: {
		if (!layer.open) {
			calendar.monthOffset = 0;
			calendar.deselect();
		}
		layer.open = !layer.open;
		if (layer.open) Qt.callLater(() => calendar.forceActiveFocus());
	}

	PopupLayer {
		id: layer

		anchorItem: root
		contentWidth: calendar.implicitWidth
		contentHeight: calendar.implicitHeight

		// For the reminder form. Asked for for as long as the popup is open,
		// as the weather panel does: a layer surface's keyboard mode is fixed
		// when it maps, so it cannot be switched on once the form appears.
		keyboardFocus: layer.open

		Calendar {
			id: calendar

			anchors.fill: parent
			today: root.now
			editable: true

			// Escape with no day picked closes the popup, as a click
			// outside it does.
			Keys.onEscapePressed: layer.open = false
			onClosed: calendar.forceActiveFocus()
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
