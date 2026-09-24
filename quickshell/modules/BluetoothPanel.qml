import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.widgets

// Device list, shown as the Bluetooth tile's detail pane.
Item {
	id: root

	// Discovery is tied to this: it never outlives the open pane, because a
	// forgotten scan drains the battery and walks over the 2.4GHz band Wi-Fi
	// is using.
	property bool active: false

	readonly property int rowHeight: 34
	readonly property int maxRows: 5

	implicitHeight: body.implicitHeight

	onActiveChanged: if (!active) Bt.stopDiscovery()
	Component.onDestruction: Bt.stopDiscovery()

	ColumnLayout {
		id: body

		anchors.fill: parent
		spacing: 2

		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 22
			Layout.leftMargin: 6
			spacing: 6

			Label {
				text: "Devices"
				color: Config.accent
				font.pixelSize: Config.fontSize - 2
			}

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: Bt.blocked ? "blocked" : Bt.discovering ? "scanning…" : ""
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				horizontalAlignment: Text.AlignRight
				elide: Text.ElideRight
			}

			IconButton {
				icon: Config.icons.search
				enabled: Bt.enabled
				tint: Bt.discovering ? Config.accent : Config.fgDim
				onTriggered: Bt.setDiscovering(!Bt.discovering)
			}
		}

		Label {
			Layout.fillWidth: true
			Layout.preferredHeight: root.rowHeight
			visible: !Bt.enabled || Bt.devices.length === 0
			text: Bt.blocked ? "Blocked by rfkill"
				: !Bt.enabled ? "Bluetooth is off"
				: Bt.discovering ? "Searching…"
				: "No paired devices"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 1
			horizontalAlignment: Text.AlignHCenter
		}

		ListView {
			Layout.fillWidth: true
			Layout.preferredHeight: Math.min(contentHeight, root.rowHeight * root.maxRows)

			visible: Bt.enabled && Bt.devices.length > 0
			clip: true
			model: Bt.devices
			boundsBehavior: Flickable.StopAtBounds

			delegate: DeviceRow {}
		}

		Label {
			Layout.fillWidth: true
			Layout.leftMargin: 6
			visible: Bt.enabled && !Bt.discovering && Bt.devices.length > 0
			text: "Search to find new devices"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 4
		}
	}

	component DeviceRow: MouseArea {
		id: row

		required property var modelData
		readonly property bool known: Bt.isKnown(modelData)
		readonly property bool working: Bt.inFlight(modelData)

		width: ListView.view.width
		height: root.rowHeight

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: Bt.activate(modelData)

		Rectangle {
			anchors.fill: parent
			anchors.bottomMargin: 1
			radius: Config.radius - 4
			color: row.containsMouse ? Config.bgAlt : "transparent"
		}

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: 8
			anchors.rightMargin: 6
			spacing: 8

			Label {
				text: Bt.icon(row.modelData)
				color: row.modelData.connected ? Config.accent : Config.fgDim
				font.pixelSize: Config.fontSize - 1
			}

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: Bt.label(row.modelData)
				elide: Text.ElideRight
				color: row.modelData.connected ? Config.accent : Config.fg
				font.pixelSize: Config.fontSize - 1
			}

			Label {
				text: Bt.status(row.modelData)
				color: row.modelData.batteryAvailable && row.modelData.battery <= 0.2
					? Config.red : Config.fgDim
				font.pixelSize: Config.fontSize - 3
				visible: text !== "" && !(row.containsMouse && row.known)
			}

			IconButton {
				icon: Config.icons.disconnect
				tint: Config.fgDim
				visible: row.modelData.connected && !row.working && row.containsMouse
				onTriggered: row.modelData.disconnect()
			}

			IconButton {
				icon: Config.icons.trash
				tint: Config.red
				visible: row.known && !row.working && row.containsMouse
				onTriggered: row.modelData.forget()
			}

			Label {
				text: Config.icons.spinner
				visible: row.working
				color: Config.accent
				font.pixelSize: Config.fontSize - 3

				RotationAnimation on rotation {
					running: row.working
					loops: Animation.Infinite
					from: 0
					to: 360
					duration: 900
				}
			}
		}
	}

	component IconButton: MouseArea {
		id: button

		property string icon
		property color tint: Config.fgDim
		property int size: Config.fontSize - 2
		signal triggered()

		implicitWidth: 20
		implicitHeight: 20
		Layout.preferredWidth: 20
		Layout.preferredHeight: 20

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: if (enabled) triggered()

		Label {
			anchors.centerIn: parent
			text: button.icon
			color: button.enabled
				? (button.containsMouse ? Config.fg : button.tint)
				: Config.fgDim
			font.pixelSize: button.size
		}
	}
}
