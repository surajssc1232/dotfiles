import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// Audio choice and start buttons, shown as the Recorder tile's detail pane.
Item {
	id: root

	property bool active: false

	// Asks the caller to take the control centre down before recording, the
	// same way the screenshot flow did.
	signal requested(string geometry)

	readonly property int rowHeight: 30

	implicitHeight: body.implicitHeight

	ColumnLayout {
		id: body

		anchors.fill: parent
		spacing: 0

		Label {
			Layout.fillWidth: true
			Layout.leftMargin: 8
			Layout.bottomMargin: 2
			text: "Audio"
			color: Config.accent
			font.pixelSize: Config.fontSize - 2
		}

		Choice {
			mode: "auto"
			icon: Config.icons.mic
			label: "Automatic"
			// Says what it will actually do, since "automatic" alone tells
			// you nothing about whether you are being recorded.
			hint: Audio.headsetConnected ? "headset mic" : "no mic connected"
		}

		Choice {
			mode: "none"
			icon: Config.icons.micOff
			label: "No audio"
			hint: "silent"
		}

		Choice {
			mode: "system"
			icon: Config.icons.volHigh
			label: "System audio"
			hint: "what you hear"
		}

		Choice {
			mode: "mic"
			icon: Config.icons.mic
			label: "Microphone"
			hint: Audio.label(Audio.source)
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.topMargin: 4
			Layout.bottomMargin: 4
			Layout.preferredHeight: 1
			color: Config.border
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			Action {
				icon: Config.icons.display
				label: "Full screen"
				onTriggered: root.requested("")
			}

			Action {
				icon: Config.icons.crop
				label: "Region"
				onTriggered: root.requested("select")
			}
		}
	}

	component Choice: MouseArea {
		id: choice

		property string mode
		property string icon
		property string label
		property string hint
		readonly property bool current: Recorder.audioMode === mode

		Layout.fillWidth: true
		Layout.preferredHeight: root.rowHeight

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: Recorder.audioMode = choice.mode

		Rectangle {
			anchors.fill: parent
			anchors.margins: 1
			radius: Config.radius - 4
			color: choice.containsMouse ? Config.bgAlt : "transparent"
			border.width: choice.current ? 1 : 0
			border.color: Config.accent
		}

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: 8
			anchors.rightMargin: 8
			spacing: 8

			Label {
				text: choice.icon
				color: choice.current ? Config.accent : Config.fgDim
				font.pixelSize: Config.fontSize - 2
			}

			Label {
				text: choice.label
				color: choice.current ? Config.accent : Config.fg
				font.pixelSize: Config.fontSize - 1
			}

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: choice.hint
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 4
				horizontalAlignment: Text.AlignRight
				elide: Text.ElideRight
			}
		}
	}

	component Action: MouseArea {
		id: action

		property string icon
		property string label
		signal triggered()

		Layout.fillWidth: true
		Layout.preferredHeight: 32

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: action.triggered()

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: action.containsMouse ? Config.accent : Config.bgAlt
			border.width: 1
			border.color: Config.border
		}

		RowLayout {
			anchors.centerIn: parent
			spacing: 6

			Label {
				text: action.icon
				color: action.containsMouse ? Config.bg : Config.red
				font.pixelSize: Config.fontSize - 2
			}

			Label {
				text: action.label
				color: action.containsMouse ? Config.bg : Config.fg
				font.pixelSize: Config.fontSize - 1
			}
		}
	}
}
