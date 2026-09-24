import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

// Top processes, refreshed only while the popup is open.
//
// The geometry below is deliberately fixed: a PopupWindow takes its size when
// it is shown, and the process list arrives a moment later. Sizing to the
// loaded rows meant the window opened at header height and the rows spilled
// out of it, so the row count — not the data — drives the height.
Item {
	id: root

	property bool active: false
	property string sortKey: "cpu"      // "cpu" or "mem"
	property var processes: []

	// Settable: the control centre asks for a shorter list than a bare popup.
	property int rows: 12
	// Own background, dropped when embedded in a panel that already has one.
	property bool framed: true
	readonly property int rowHeight: 24
	readonly property int headerHeight: 22

	implicitWidth: 340
	implicitHeight: (root.framed ? Config.padding * 2 : 0)
		+ headerHeight + 9 + rows * rowHeight

	onActiveChanged: if (active) refresh()

	function refresh() {
		if (!scanner.running) scanner.running = true;
	}

	// %cpu from ps is an average over the process lifetime, which is what
	// makes the ordering stable enough to click on.
	Process {
		id: scanner

		command: ["sh", "-c",
			"ps -eo pid=,%cpu=,%mem=,comm= --sort=-%" + root.sortKey + " | head -n " + root.rows]

		stdout: StdioCollector {
			onStreamFinished: {
				const out = [];
				for (const line of this.text.trim().split("\n")) {
					const m = line.trim().match(/^(\d+)\s+(\S+)\s+(\S+)\s+(.+)$/);
					if (!m) continue;
					out.push({ pid: m[1], cpu: parseFloat(m[2]), mem: parseFloat(m[3]), name: m[4] });
				}
				root.processes = out;
			}
		}
	}

	Process { id: killer }

	function signalProcess(pid: string, sig: string) {
		killer.command = ["kill", sig, pid];
		killer.running = true;
		// Give the process a moment to go away before redrawing the list.
		refreshDelay.restart();
	}

	Timer {
		id: refreshDelay
		interval: 400
		onTriggered: root.refresh()
	}

	Timer {
		interval: 3000
		running: root.active
		repeat: true
		onTriggered: root.refresh()
	}

	Rectangle {
		anchors.fill: parent
		visible: root.framed
		radius: Config.radius
		color: Config.bg
		border.width: 1
		border.color: Config.border
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: root.framed ? Config.padding : 0
		spacing: 0

		// ---- header / sort toggle ----
		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: root.headerHeight
			spacing: 6

			Label {
				Layout.fillWidth: true
				text: "Processes"
				color: Config.accent
			}

			SortTab { label: "CPU"; key: "cpu" }
			SortTab { label: "MEM"; key: "mem" }
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			Layout.topMargin: 4
			Layout.bottomMargin: 4
			color: Config.border
		}

		// One slot per row, filled in as data arrives. Empty slots keep the
		// window a constant size instead of making it jump on every refresh.
		Repeater {
			model: root.rows

			MouseArea {
				id: row

				required property int index
				readonly property var proc: root.processes[index] ?? null

				Layout.fillWidth: true
				Layout.preferredHeight: root.rowHeight
				implicitHeight: root.rowHeight

				hoverEnabled: proc !== null

				Rectangle {
					anchors.fill: parent
					radius: Config.radius - 4
					color: row.containsMouse ? Config.bgAlt : "transparent"
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 6
					anchors.rightMargin: 4
					spacing: 6
					visible: row.proc !== null

					Label {
						Layout.fillWidth: true
						text: row.proc?.name ?? ""
						font.pixelSize: Config.fontSize - 1
						elide: Text.ElideRight
					}

					Label {
						text: row.proc?.pid ?? ""
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
					}

					Label {
						Layout.preferredWidth: 44
						text: (row.proc?.cpu ?? 0).toFixed(1) + "%"
						horizontalAlignment: Text.AlignRight
						font.pixelSize: Config.fontSize - 2
						color: root.sortKey === "cpu" ? Config.fg : Config.fgDim
					}

					Label {
						Layout.preferredWidth: 44
						text: (row.proc?.mem ?? 0).toFixed(1) + "%"
						horizontalAlignment: Text.AlignRight
						font.pixelSize: Config.fontSize - 2
						color: root.sortKey === "mem" ? Config.fg : Config.fgDim
					}

					// Left click sends SIGTERM, right click SIGKILL. Only shown
					// on the hovered row, so it is hard to hit by accident.
					MouseArea {
						id: killButton

						Layout.preferredWidth: 20
						Layout.preferredHeight: 20
						implicitWidth: 20
						implicitHeight: 20

						opacity: row.containsMouse ? 1 : 0
						enabled: row.containsMouse
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.RightButton

						onClicked: event => root.signalProcess(row.proc.pid,
							event.button === Qt.RightButton ? "-KILL" : "-TERM")

						Rectangle {
							anchors.fill: parent
							radius: 4
							color: killButton.containsMouse ? Config.red : "transparent"
						}

						Label {
							anchors.centerIn: parent
							text: Config.icons.kill
							font.pixelSize: Config.fontSize - 2
							color: killButton.containsMouse ? Config.bg : Config.red
						}
					}
				}
			}
		}
	}

	// CPU / MEM sort selector.
	component SortTab: MouseArea {
		id: tab

		property string label
		property string key
		readonly property bool selected: root.sortKey === key

		Layout.preferredWidth: 42
		Layout.preferredHeight: 20
		implicitWidth: 42
		implicitHeight: 20

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			root.sortKey = tab.key;
			root.refresh();
		}

		Rectangle {
			anchors.fill: parent
			radius: 4
			color: tab.selected ? Config.bgAlt : "transparent"
			border.width: 1
			border.color: tab.selected ? Config.border : "transparent"
		}

		Label {
			anchors.centerIn: parent
			text: tab.label
			font.pixelSize: Config.fontSize - 3
			color: tab.selected ? Config.accent : Config.fgDim
		}
	}
}
