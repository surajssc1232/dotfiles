import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Asked once a recording finishes: keep it, copy it, or throw it away.
//
// The file is already written by the time this appears — wf-recorder has to
// finalise the container on disk — so "discard" deletes rather than prevents.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	property string path: ""
	property bool armed: false

	visible: armed && path !== ""

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

	// Only the panel is clickable; the rest of the screen stays usable so this
	// cannot trap you if it is ignored.
	mask: Region { item: card }

	function close() {
		root.armed = false;
		root.path = "";
	}

	Connections {
		target: Recorder

		function onFinished(path) {
			root.path = path;
			root.armed = true;
		}
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
					text: Config.icons.record
					color: Config.red
					font.pixelSize: Config.fontSize + 2
				}

				ColumnLayout {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					spacing: 0

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: "Recording finished"
						elide: Text.ElideRight
					}

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: root.path.split("/").pop()
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
						elide: Text.ElideMiddle
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Action {
					label: "Save"
					icon: Config.icons.check
					accent: Config.green
					onTriggered: {
						Recorder.keep(root.path);
						root.close();
					}
				}

				Action {
					label: "Copy"
					icon: Config.icons.clipboard
					accent: Config.accent
					onTriggered: {
						Recorder.copy(root.path);
						root.close();
					}
				}

				Action {
					label: "Delete"
					icon: Config.icons.trash
					accent: Config.red
					onTriggered: {
						Recorder.discard(root.path);
						root.close();
					}
				}
			}

			Label {
				Layout.fillWidth: true
				text: "Saved in ~/Videos/Recordings either way — copy puts it on the clipboard too"
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
