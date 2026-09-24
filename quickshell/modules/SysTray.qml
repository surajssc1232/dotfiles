import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.widgets

Pill {
	id: root

	visible: SystemTray.items.values.length > 0

	Repeater {
		model: SystemTray.items

		MouseArea {
			id: entry
			required property SystemTrayItem modelData

			Layout.preferredWidth: Config.fontSize + 4
			Layout.preferredHeight: Config.fontSize + 4

			acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
			hoverEnabled: true

			onClicked: event => {
				if (event.button === Qt.LeftButton) modelData.activate();
				else if (event.button === Qt.MiddleButton) modelData.secondaryActivate();
				else if (modelData.hasMenu) menuAnchor.open();
			}

			IconImage {
				anchors.fill: parent
				source: entry.modelData.icon
			}

			QsMenuAnchor {
				id: menuAnchor
				menu: entry.modelData.menu
				anchor.item: entry
				anchor.rect.y: entry.height + Config.barMargin
			}
		}
	}
}
