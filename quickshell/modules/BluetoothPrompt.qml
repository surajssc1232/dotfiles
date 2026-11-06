import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Asked whenever a Bluetooth device wants something from the pairing agent:
// permission to pair, a code to compare, a code to type, or a PIN. Nothing is
// ever answered on your behalf — the agent in Bt waits for a choice here.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property var request: Bt.request
	readonly property string kind: request?.kind ?? ""

	visible: request !== null

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}

	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	focusable: true
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
	WlrLayershell.namespace: "quickshell-bluetooth-prompt"

	// Only the card is clickable; the rest of the screen stays usable.
	mask: Region { item: card }

	readonly property string title: {
		switch (root.kind) {
		case "authorize": return "Pair with this device?";
		case "confirm": return "Does the code match?";
		case "display": return "Type this code on the device";
		case "pin": return "Enter the device's PIN";
		case "service": return "Allow this device to connect?";
		}
		return "";
	}

	readonly property string hint: {
		switch (root.kind) {
		case "authorize": return "It did not ask for a code. Only accept if you just started pairing it.";
		case "confirm": return "The same number should be showing on the device.";
		case "display": return "Then press Enter on it. This closes by itself once it pairs.";
		case "pin": return "Often 0000 or 1234 — check the device's manual.";
		case "service": return "An already paired device wants to use a new feature.";
		}
		return "";
	}

	Panel {
		id: card

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		anchors.topMargin: Config.barMargin * 2 + Config.barHeight

		implicitWidth: 340
		implicitHeight: body.implicitHeight + Config.padding * 2

		ColumnLayout {
			id: body

			anchors.fill: parent
			anchors.margins: Config.padding
			spacing: 8

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Label {
					text: Config.icons.bluetooth
					color: Config.accent
					font.pixelSize: Config.fontSize + 2
				}

				ColumnLayout {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					spacing: 0

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: root.title
						elide: Text.ElideRight
					}

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: root.request
							? root.request.name + (root.request.address ? "  ·  " + root.request.address : "")
							: ""
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
						elide: Text.ElideMiddle
					}
				}
			}

			// The code itself, big enough to read across a desk.
			Label {
				Layout.fillWidth: true
				visible: root.kind === "confirm" || root.kind === "display"
				text: (root.request?.code ?? "").replace(/(\d{3})(\d{3})/, "$1 $2")
				color: Config.accent
				font.pixelSize: Config.fontSize + 12
				font.letterSpacing: 2
				horizontalAlignment: Text.AlignHCenter
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 32
				visible: root.kind === "pin"
				radius: Config.radius - 4
				color: Config.bg
				border.width: 1
				border.color: pin.activeFocus ? Config.accent : Config.border

				TextInput {
					id: pin

					anchors.fill: parent
					anchors.leftMargin: 8
					anchors.rightMargin: 8

					verticalAlignment: TextInput.AlignVCenter
					color: Config.fg
					font.family: Config.font
					font.pixelSize: Config.fontSize - 1
					selectByMouse: true
					selectionColor: Config.accent
					clip: true

					onVisibleChanged: {
						text = "";
						if (visible) forceActiveFocus();
					}

					onAccepted: if (text !== "") Bt.answerPin(text)
					Keys.onEscapePressed: Bt.reject()
				}
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Action {
					visible: root.kind !== "display"
					label: root.kind === "pin" ? "Pair" : root.kind === "confirm" ? "Matches" : "Accept"
					icon: Config.icons.check
					accent: Config.green
					onTriggered: root.kind === "pin" ? Bt.answerPin(pin.text) : Bt.accept()
				}

				Action {
					label: root.kind === "display" ? "Cancel" : "Reject"
					icon: Config.icons.close
					accent: Config.red
					onTriggered: Bt.reject()
				}
			}

			Label {
				Layout.fillWidth: true
				text: root.hint
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 4
				wrapMode: Text.WordWrap
			}
		}
	}

	component Action: MouseArea {
		id: action

		property string label
		property string icon
		property color accent: Config.accent
		signal triggered()

		Layout.fillWidth: true
		Layout.preferredHeight: 32

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: action.triggered()

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: action.containsMouse ? action.accent : Config.bgAlt
			border.width: 1
			border.color: action.containsMouse ? action.accent : Config.border
		}

		RowLayout {
			anchors.centerIn: parent
			spacing: 6

			Label {
				text: action.icon
				color: action.containsMouse ? Config.bg : action.accent
				font.pixelSize: Config.fontSize - 3
			}

			Label {
				text: action.label
				color: action.containsMouse ? Config.bg : Config.fg
				font.pixelSize: Config.fontSize - 1
			}
		}
	}
}
