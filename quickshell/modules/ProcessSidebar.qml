import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.widgets

// A system monitor that slides in from the right edge of the screen while the
// cursor is on it: CPU and memory history as graphs, and the busiest
// processes under them.
//
// The window runs to the very edge of the screen, with the panel inset from
// it, so a cursor pushed all the way right is always over the hover strip.
// Closed, the only thing on screen is a few invisible pixels along the edge
// to hover; the window's input region is trimmed to that strip, or to the
// panel while it is out, so the rest of the screen stays clickable.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property int panelWidth: 340
	readonly property int edgeWidth: 6
	readonly property int points: 60

	property bool open: false

	// Graph history, newest last, as percentages.
	property var cpuHistory: []
	property var memHistory: []
	property int cpu: 0
	property int mem: 0
	property string memText: ""
	property string memDetail: ""
	property int cores: 1

	// Processes, from `top`: [{ pid, name, cpu, mem }]
	property var processes: []
	property string sortKey: "CPU"

	// Rows under the cursor. The list holds still while one is, so a refresh
	// cannot reorder it from under a click.
	property int hoveredRows: 0

	property real lastIdle: 0
	property real lastTotal: 0

	anchors {
		top: true
		right: true
		bottom: true
	}

	margins {
		top: Config.barMargin * 2 + Config.barHeight + Config.barMargin
		bottom: Config.barMargin
	}

	implicitWidth: panelWidth + Config.barMargin + 40
	mask: Region { item: hit }

	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	WlrLayershell.namespace: "process-sidebar"

	// ---- opening and closing ----

	// The one area that counts as "on the sidebar": a thin strip at the edge
	// while closed, widening to cover the panel and the gap between it and the
	// edge once open. Being a single area matters: with the strip and the panel
	// as separate regions, a cursor in the gap beside the open panel was over
	// neither, so the panel closed, the strip came back, it opened again, and so
	// on without end.
	Item {
		id: hit

		anchors.right: parent.right
		anchors.top: parent.top
		anchors.bottom: parent.bottom
		width: root.open ? root.panelWidth + Config.barMargin + root.edgeWidth : root.edgeWidth
	}

	// On the window itself, not on `hit`: a handler on `hit` is a sibling
	// under the panel, and once the pointer is over the panel's own hoverable
	// rows it stopped counting as hovered, so the panel closed under the
	// cursor. A handler on the window sees the pointer over every child.
	HoverHandler {
		id: hover

		// How far from the right screen edge the cursor was when last seen.
		// Pushed against the edge it can fall outside this surface for a
		// moment; that is not a reason to put the panel away.
		onPointChanged: if (hovered) root.edgeGap = root.width - point.position.x
	}

	property real edgeGap: 100
	readonly property bool leftViaEdge: root.edgeGap <= 4

	// The short delay on closing keeps a cursor that skims out and back in
	// from collapsing the panel.
	Timer {
		id: closer

		interval: root.leftViaEdge ? 2500 : 160
		running: root.open && !hover.hovered
		onTriggered: root.open = false
	}

	Connections {
		target: hover

		function onHoveredChanged(): void {
			if (hover.hovered) root.open = true;
		}
	}

	// ---- sampling ----

	// Kibibytes as MB below a gigabyte, GB above it.
	function size(kb: real): string {
		if (kb >= 1048576) return (kb / 1048576).toFixed(1) + " GB";
		if (kb >= 1024) return Math.round(kb / 1024) + " MB";
		return Math.round(kb) + " KB";
	}

	// top prints a task's memory in KiB, switching to m / g / t suffixes once
	// the number gets wide.
	function topKb(text: string): real {
		const m = text.replace(",", ".").match(/^([\d.]+)([kmgt]?)$/i);
		if (!m) return 0;
		const scale = { "": 1, k: 1, m: 1024, g: 1048576, t: 1073741824 };
		return parseFloat(m[1]) * scale[m[2].toLowerCase()];
	}

	function parseSample(out: string) {
		const lines = out.trim().split("\n");
		if (lines.length < 4) return;

		const cols = lines[0].split(/\s+/).slice(1).map(Number);
		const idle = cols[3] + (cols[4] ?? 0);
		const total = cols.reduce((a, b) => a + b, 0);

		if (root.lastTotal > 0) {
			const dTotal = total - root.lastTotal;
			const dIdle = idle - root.lastIdle;
			if (dTotal > 0) root.cpu = Math.round((1 - dIdle / dTotal) * 100);
		}
		root.lastIdle = idle;
		root.lastTotal = total;

		const kb = {};
		for (const line of lines.slice(1)) {
			const m = line.match(/^(\w+):\s+(\d+)/);
			if (m) kb[m[1]] = Number(m[2]);
		}
		const memTotal = kb.MemTotal ?? 0;
		const memAvailable = kb.MemAvailable ?? 0;
		if (memTotal > 0) {
			root.mem = Math.round((1 - memAvailable / memTotal) * 100);
			root.memText = root.size(memTotal - memAvailable) + " / " + root.size(memTotal);
			const swapUsed = (kb.SwapTotal ?? 0) - (kb.SwapFree ?? 0);
			root.memDetail = "Free " + root.size(memAvailable) + " · Cached " + root.size(kb.Cached ?? 0)
				+ ((kb.SwapTotal ?? 0) > 0
					? " · Swap " + root.size(swapUsed) + " / " + root.size(kb.SwapTotal) : "");
		}

		const push = (history, value) => {
			const next = history.concat([value]);
			return next.length > root.points ? next.slice(next.length - root.points) : next;
		};
		root.cpuHistory = push(root.cpuHistory, root.cpu);
		root.memHistory = push(root.memHistory, root.mem);
	}

	// The graphs run all the time, at two seconds a sample: two minutes of
	// history, for a read of two files.
	Timer {
		interval: 2000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: sampler.running = true
	}

	Process {
		id: sampler

		command: ["sh", "-c",
			"head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable|Cached|SwapTotal|SwapFree):' /proc/meminfo"]

		stdout: StdioCollector {
			onStreamFinished: root.parseSample(this.text)
		}
	}

	Process {
		command: ["nproc"]
		running: true

		stdout: StdioCollector {
			onStreamFinished: root.cores = Math.max(1, parseInt(this.text) || 1)
		}
	}

	// The process list is only worth fetching while it can be seen. `top`
	// is asked for two rounds, half a second apart, and the second one is
	// kept: the first is an average over each process's whole life.
	function refreshProcesses() {
		if (!scanner.running) scanner.running = true;
	}

	onOpenChanged: if (open) refreshProcesses()
	onSortKeyChanged: if (open) refreshProcesses()

	Timer {
		interval: 2000
		running: root.open && root.hoveredRows <= 0
		repeat: true
		onTriggered: root.refreshProcesses()
	}

	Process {
		id: scanner

		command: ["sh", "-c",
			"top -b -n2 -d0.5 -w 160 -o %" + root.sortKey
			+ " | awk '/^top -/{buf=\"\"} {buf=buf $0 \"\\n\"} END{printf \"%s\", buf}' | head -n 48"]

		stdout: StdioCollector {
			onStreamFinished: {
				const out = [];
				let inRows = false;
				for (const line of this.text.split("\n")) {
					if (/^\s*PID\b/.test(line)) { inRows = true; continue; }
					if (!inRows) continue;
					const m = line.trim().match(/^(\d+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+\S+\s+(\S)\s+([\d.,]+)\s+([\d.,]+)\s+(\S+)\s+(.+)$/);
					if (!m) continue;
					out.push({
						pid: m[1],
						user: m[2],
						res: root.topKb(m[3]),
						state: m[4],
						cpu: parseFloat(m[5].replace(",", ".")),
						mem: parseFloat(m[6].replace(",", ".")),
						time: m[7],
						name: m[8]
					});
				}
				root.processes = out.slice(0, 30);
			}
		}
	}

	Process { id: killer }

	function signal(pid: string, name: string) {
		killer.command = ["kill", "-" + name, pid];
		killer.running = true;
		// Give it a moment to go away before the list is redrawn.
		afterKill.restart();
	}

	Timer {
		id: afterKill

		interval: 500
		onTriggered: root.refreshProcesses()
	}

	// ---- the panel ----

	Panel {
		id: panel

		width: root.panelWidth
		height: parent.height
		y: 0
		// Off the edge when closed.
		x: root.open ? parent.width - root.panelWidth - Config.barMargin : parent.width + 8

		Behavior on x {
			NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Config.padding
			spacing: 12

			Label {
				text: "System"
				color: Config.accent
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Config.border
			}

			// ---- CPU ----
			GraphBlock {
				Layout.fillWidth: true
				title: "CPU"
				value: root.cpu + "%"
				detail: root.cores + " cores"
				values: root.cpuHistory
				tone: Config.accent
			}

			// ---- memory ----
			GraphBlock {
				Layout.fillWidth: true
				title: "MEMORY"
				value: root.mem + "%"
				detail: root.memText
				values: root.memHistory
				tone: Config.blue
			}

			Label {
				Layout.fillWidth: true
				text: root.memDetail
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				elide: Text.ElideRight
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 1
				color: Config.border
			}

			// ---- processes ----
			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Label {
					Layout.fillWidth: true
					text: "Processes"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
				}

				SortTab { label: "CPU"; key: "CPU" }
				SortTab { label: "MEM"; key: "MEM" }
			}

			Flickable {
				id: flick

				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				contentWidth: width
				contentHeight: list.implicitHeight
				boundsBehavior: Flickable.StopAtBounds
				flickableDirection: Flickable.VerticalFlick

				// Thin scroll indicator, only when there is more than fits.
				Rectangle {
					x: parent.width - width
					y: flick.visibleArea.yPosition * flick.height
					width: 3
					height: flick.visibleArea.heightRatio * flick.height
					radius: 1.5
					color: Config.fgDim
					opacity: flick.visibleArea.heightRatio < 1 ? 0.6 : 0
					z: 2
				}

				ColumnLayout {
					id: list

					width: flick.width - 8
					spacing: 4

								Repeater {
									model: root.processes

									MouseArea {
										id: row

										required property var modelData

										// Asked once before anything is killed.
										property bool armed: false

										readonly property real share: root.sortKey === "CPU"
											? Math.min(100, modelData.cpu / root.cores)
											: Math.min(100, modelData.mem)

										Layout.fillWidth: true
										Layout.preferredHeight: 40
										hoverEnabled: true
										onContainsMouseChanged: {
											if (!containsMouse) armed = false;
											root.hoveredRows += containsMouse ? 1 : -1;
										}

										Component.onDestruction: if (containsMouse) root.hoveredRows -= 1

										Timer {
											interval: 4000
											running: row.armed
											onTriggered: row.armed = false
										}

										Rectangle {
											anchors.fill: parent
											radius: Config.radius - 4
											color: row.containsMouse ? Config.bgAlt : "transparent"
										}

										ColumnLayout {
											anchors.fill: parent
											anchors.leftMargin: 6
											anchors.rightMargin: 6
											spacing: 2

											RowLayout {
												Layout.fillWidth: true
												Layout.topMargin: 3
												spacing: 8

												Label {
													Layout.fillWidth: true
													Layout.minimumWidth: 0
													text: row.modelData.name
													elide: Text.ElideRight
													font.pixelSize: Config.fontSize - 1
												}

												Label {
													Layout.preferredWidth: 44
													horizontalAlignment: Text.AlignRight
													text: (row.modelData.cpu / root.cores).toFixed(1) + "%"
													color: root.sortKey === "CPU" ? Config.accent : Config.fgDim
													font.pixelSize: Config.fontSize - 2
												}

												Label {
													Layout.preferredWidth: 62
													horizontalAlignment: Text.AlignRight
													text: root.size(row.modelData.res)
													color: root.sortKey === "MEM" ? Config.blue : Config.fgDim
													font.pixelSize: Config.fontSize - 2
												}
											}

											RowLayout {
												Layout.fillWidth: true
												spacing: 6

												Label {
													Layout.fillWidth: true
													Layout.minimumWidth: 0
													text: "pid " + row.modelData.pid + " · " + row.modelData.user
														+ " · " + row.modelData.time
													color: Config.fgDim
													font.pixelSize: Config.fontSize - 4
													elide: Text.ElideRight
												}

												// Hover shows the kill button; one click arms it, a second
												// picks how hard to end the process. The slot is always
												// the same width, so the text beside it never moves.
												Item {
													Layout.preferredWidth: 96
													Layout.preferredHeight: 16

													KillButton {
														anchors.right: parent.right
														opacity: row.containsMouse && !row.armed ? 1 : 0
														enabled: opacity > 0
														text: "kill"
														tone: Config.red
														onClicked: row.armed = true
													}

													Row {
														anchors.right: parent.right
														spacing: 6
														opacity: row.armed ? 1 : 0
														enabled: row.armed

														KillButton {
															text: "quit"
															tone: Config.yellow
															onClicked: { root.signal(row.modelData.pid, "TERM"); row.armed = false; }
														}

														KillButton {
															text: "force"
															tone: Config.red
															onClicked: { root.signal(row.modelData.pid, "KILL"); row.armed = false; }
														}
													}
												}
											}

											Rectangle {
												Layout.fillWidth: true
												Layout.preferredHeight: 3
												radius: 1.5
												color: Config.bg

												Rectangle {
													width: parent.width * row.share / 100
													height: parent.height
													radius: 1.5
													color: root.sortKey === "CPU" ? Config.accent : Config.blue

													Behavior on width { NumberAnimation { duration: 300 } }
												}
											}
										}
									}
								}
				}
			}

		}
	}

	// ---- parts ----

	component KillButton: MouseArea {
		id: button

		property string text
		property color tone

		implicitWidth: label.implicitWidth + 12
		implicitHeight: 16
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor

		Rectangle {
			anchors.fill: parent
			radius: 4
			color: button.containsMouse ? Qt.rgba(button.tone.r, button.tone.g, button.tone.b, 0.25)
				: "transparent"
			border.width: 1
			border.color: button.tone
		}

		Label {
			id: label

			anchors.centerIn: parent
			text: button.text
			color: button.tone
			font.pixelSize: Config.fontSize - 4
		}
	}

	component SortTab: MouseArea {
		id: tab

		property string label
		property string key

		implicitWidth: text.implicitWidth + 12
		implicitHeight: 20
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.sortKey = tab.key

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: root.sortKey === tab.key ? Config.bgAlt : "transparent"
			border.width: tab.containsMouse ? 1 : 0
			border.color: Config.border
		}

		Label {
			id: text

			anchors.centerIn: parent
			text: tab.label
			color: root.sortKey === tab.key ? Config.accent : Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}
	}

	// A title, the current figure, and a history graph under them.
	component GraphBlock: ColumnLayout {
		id: block

		property string title
		property string value
		property string detail
		property var values: []
		property color tone

		spacing: 6

		RowLayout {
			Layout.fillWidth: true

			Label {
				text: block.title
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				font.letterSpacing: 1
			}

			Item { Layout.fillWidth: true }

			Label {
				text: block.detail
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
			}

			Label {
				text: block.value
				color: block.tone
				font.pixelSize: Config.fontSize + 6
				font.weight: Font.DemiBold
			}
		}

		Canvas {
			id: graph

			Layout.fillWidth: true
			Layout.preferredHeight: 84

			property var values: block.values
			property color tone: block.tone
			property color grid: Config.border

			onValuesChanged: requestPaint()
			onToneChanged: requestPaint()
			onGridChanged: requestPaint()
			onWidthChanged: requestPaint()

			onPaint: {
				const ctx = getContext("2d");
				ctx.reset();

				const w = width;
				const h = height;

				// Quarter lines.
				ctx.strokeStyle = graph.grid;
				ctx.lineWidth = 1;
				ctx.globalAlpha = 0.6;
				for (let i = 1; i < 4; i++) {
					const y = Math.round(h * i / 4) + 0.5;
					ctx.beginPath();
					ctx.moveTo(0, y);
					ctx.lineTo(w, y);
					ctx.stroke();
				}
				ctx.globalAlpha = 1;

				const v = graph.values;
				if (v.length < 2) return;

				// Newest sample at the right edge, history running left.
				const step = w / (root.points - 1);
				const x0 = w - (v.length - 1) * step;
				const at = i => ({ x: x0 + i * step, y: h - 2 - (h - 4) * Math.min(100, v[i]) / 100 });

				ctx.beginPath();
				ctx.moveTo(at(0).x, h);
				for (let i = 0; i < v.length; i++) ctx.lineTo(at(i).x, at(i).y);
				ctx.lineTo(at(v.length - 1).x, h);
				ctx.closePath();
				const fill = ctx.createLinearGradient(0, 0, 0, h);
				fill.addColorStop(0, Qt.rgba(graph.tone.r, graph.tone.g, graph.tone.b, 0.45));
				fill.addColorStop(1, Qt.rgba(graph.tone.r, graph.tone.g, graph.tone.b, 0.02));
				ctx.fillStyle = fill;
				ctx.fill();

				ctx.beginPath();
				for (let i = 0; i < v.length; i++) {
					if (i === 0) ctx.moveTo(at(i).x, at(i).y);
					else ctx.lineTo(at(i).x, at(i).y);
				}
				ctx.strokeStyle = graph.tone;
				ctx.lineWidth = 1.8;
				ctx.lineJoin = "round";
				ctx.stroke();
			}
		}
	}
}
