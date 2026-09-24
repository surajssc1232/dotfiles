import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

// Network list, shown as the Wi-Fi tile's detail pane.
Item {
	id: root

	// Driven by the owning tile: gates scanning, and clears any half-typed
	// password when the pane is put away.
	property bool active: false

	readonly property int rowHeight: 34
	readonly property int maxRows: 5

	// SSID whose password field is open, if any. The control centre watches
	// this to decide whether the layer needs a keyboard.
	property string expanded: ""
	readonly property bool wantsKeyboard: expanded !== ""

	implicitHeight: body.implicitHeight

	onActiveChanged: {
		Network.active = active;
		root.expanded = "";
		Network.clearError();
		if (active) {
			Network.refresh();
			Network.rescan();
		}
	}

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
				text: "Networks"
				color: Config.accent
				font.pixelSize: Config.fontSize - 2
			}

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: Network.scanning ? "scanning…" : ""
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				horizontalAlignment: Text.AlignRight
				elide: Text.ElideRight
			}

			IconButton {
				icon: Config.icons.refresh
				enabled: Network.wifiEnabled
				tint: Network.scanning ? Config.accent : Config.fgDim
				onTriggered: Network.rescan()
			}
		}

		Label {
			Layout.fillWidth: true
			Layout.preferredHeight: root.rowHeight
			visible: !Network.wifiEnabled || Network.networks.length === 0
			text: !Network.wifiEnabled ? "Wi-Fi is off" : "No networks found"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 1
			horizontalAlignment: Text.AlignHCenter
		}

		ListView {
			id: list

			Layout.fillWidth: true
			Layout.preferredHeight: Math.min(contentHeight, root.rowHeight * root.maxRows)

			visible: Network.wifiEnabled && Network.networks.length > 0
			clip: true
			model: Network.networks
			boundsBehavior: Flickable.StopAtBounds
			// Recycling would carry a half-typed password to another row.
			reuseItems: false

			delegate: NetworkRow {}
		}
	}

	component NetworkRow: Column {
		id: row

		required property var modelData
		required property int index
		readonly property string ssid: modelData.ssid
		readonly property bool isExpanded: root.expanded === ssid
		readonly property bool isBusy: Network.busySsid === ssid
		readonly property bool hasError: Network.errorSsid === ssid

		width: ListView.view.width

		MouseArea {
			id: hit

			width: parent.width
			height: root.rowHeight
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor

			onClicked: {
				if (row.isBusy || row.modelData.active) return;
				Network.clearError();

				// A stored profile or an open network needs nothing more than a
				// click; anything else has to be asked for a key first.
				if (row.modelData.saved || !row.modelData.secure) {
					root.expanded = "";
					Network.activate(row.ssid);
				} else {
					root.expanded = row.isExpanded ? "" : row.ssid;
					// A row near the bottom would otherwise open its password
					// field below the fold.
					if (root.expanded)
						list.positionViewAtIndex(row.index, ListView.Contain);
				}
			}

			Rectangle {
				anchors.fill: parent
				anchors.bottomMargin: 1
				radius: Config.radius - 4
				color: hit.containsMouse || row.isExpanded ? Config.bgAlt : "transparent"
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 6
				spacing: 8

				SignalBars {
					strength: row.modelData.signal
					tint: row.modelData.active ? Config.accent : Config.fg
				}

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: row.ssid
					elide: Text.ElideRight
					color: row.modelData.active ? Config.accent : Config.fg
					font.pixelSize: Config.fontSize - 1
				}

				Label {
					text: Config.icons.lock
					visible: row.modelData.secure
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
				}

				Label {
					text: Config.icons.spinner
					visible: row.isBusy
					color: Config.accent
					font.pixelSize: Config.fontSize - 3

					RotationAnimation on rotation {
						running: row.isBusy
						loops: Animation.Infinite
						from: 0
						to: 360
						duration: 900
					}
				}

				IconButton {
					icon: Config.icons.disconnect
					tint: Config.fgDim
					visible: row.modelData.active && !row.isBusy && hit.containsMouse
					onTriggered: Network.disconnect()
				}

				IconButton {
					icon: Config.icons.trash
					tint: Config.red
					visible: row.modelData.saved && !row.isBusy && hit.containsMouse
					onTriggered: {
						root.expanded = "";
						Network.forget(row.ssid);
					}
				}

				Label {
					text: Config.icons.check
					visible: row.modelData.active && !hit.containsMouse && !row.isBusy
					color: Config.accent
					font.pixelSize: Config.fontSize - 3
				}
			}
		}

		// ---- password entry ----
		Item {
			width: parent.width
			height: row.isExpanded ? 36 : 0
			visible: height > 0
			clip: true

			Behavior on height {
				NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 6
				anchors.topMargin: 2
				anchors.bottomMargin: 6
				spacing: 6

				Rectangle {
					Layout.fillWidth: true
					Layout.fillHeight: true

					radius: Config.radius - 4
					color: Config.bg
					border.width: 1
					border.color: field.activeFocus ? Config.accent : Config.border

					Label {
						anchors.left: parent.left
						anchors.leftMargin: 8
						anchors.verticalCenter: parent.verticalCenter
						text: Config.icons.key
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 4
					}

					TextInput {
						id: field

						anchors.fill: parent
						anchors.leftMargin: 26
						anchors.rightMargin: 8

						verticalAlignment: TextInput.AlignVCenter
						color: Config.fg
						font.family: Config.font
						font.pixelSize: Config.fontSize - 1
						echoMode: TextInput.Password
						selectByMouse: true
						selectionColor: Config.accent
						clip: true

						onVisibleChanged: if (visible) forceActiveFocus()
						Component.onCompleted: if (visible) forceActiveFocus()

						onAccepted: row.submit()
						Keys.onEscapePressed: root.expanded = ""

						Label {
							anchors.verticalCenter: parent.verticalCenter
							text: "Password"
							color: Config.fgDim
							font.pixelSize: Config.fontSize - 2
							visible: !field.text && !field.activeFocus
						}
					}
				}

				IconButton {
					icon: Config.icons.check
					tint: field.text ? Config.green : Config.fgDim
					enabled: field.text.length > 0
					onTriggered: row.submit()
				}
			}
		}

		function submit() {
			if (!field.text) return;
			const password = field.text;
			field.text = "";
			root.expanded = "";
			Network.connectTo(row.ssid, password);
		}

		// ---- failure message ----
		Item {
			width: parent.width
			height: row.hasError ? 26 : 0
			visible: height > 0
			clip: true

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: 8
				anchors.rightMargin: 8
				anchors.bottomMargin: 4
				spacing: 6

				Label {
					text: Config.icons.warning
					color: Config.red
					font.pixelSize: Config.fontSize - 4
				}

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: Network.errorText
					color: Config.red
					font.pixelSize: Config.fontSize - 3
					elide: Text.ElideRight
				}
			}
		}
	}

	// Four bars, filled to match the signal percentage.
	component SignalBars: Item {
		id: bars

		property int strength: 0
		property color tint: Config.fg

		implicitWidth: 17
		implicitHeight: 13
		Layout.preferredWidth: 17
		Layout.preferredHeight: 13
		Layout.alignment: Qt.AlignVCenter

		Repeater {
			model: 4

			Rectangle {
				required property int index

				width: 3
				height: 4 + index * 3
				x: index * 5
				y: bars.height - height
				radius: 1
				color: bars.strength >= index * 25 + 13
					? bars.tint
					: Qt.rgba(bars.tint.r, bars.tint.g, bars.tint.b, 0.25)
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
