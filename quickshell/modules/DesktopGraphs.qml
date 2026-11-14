import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// Live CPU, memory and network sparklines, painted on the wallpaper.
// Lives inside WallpaperLayer so it always sits above the picture and under
// every window. Purely decorative: it takes no input.
Rectangle {
	id: root

	implicitWidth: 300
	implicitHeight: column.implicitHeight + Config.inset * 2
	radius: Config.radius
	color: Qt.alpha(Config.bg, 0.9)
	border.width: 1
	border.color: Qt.alpha(Config.fg, 0.08)

	component Graph: ColumnLayout {
		id: graph

		property string icon
		property string title
		property string value
		property var series: []
		property var series2: []          // optional second line (upload)
		property real max: 100             // 0 = scale to the data
		property color lineColor: Config.accent
		property color line2Color: Config.blue

		Layout.fillWidth: true
		spacing: 4

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			Label { text: graph.icon; color: graph.lineColor; font.pixelSize: Config.fontSize - 1 }
			Label { text: graph.title; color: Config.fgDim; font.pixelSize: Config.fontSize - 1 }
			Item { Layout.fillWidth: true }
			Label { text: graph.value; font.bold: true; font.pixelSize: Config.fontSize - 1 }
		}

		Canvas {
			id: canvas

			Layout.fillWidth: true
			Layout.preferredHeight: 38

			readonly property real ceiling: graph.max > 0 ? graph.max
				: Math.max(1024, ...graph.series, ...graph.series2) * 1.15

			onPaint: {
				const ctx = getContext("2d");
				ctx.reset();
				const draw = (data, col, fill) => {
					if (data.length < 2) return;
					const step = width / (SysStats.length - 1);
					const x0 = width - (data.length - 1) * step;
					const yOf = v => height - 1 - (Math.min(v, ceiling) / ceiling) * (height - 2);
					ctx.beginPath();
					ctx.moveTo(x0, yOf(data[0]));
					for (let i = 1; i < data.length; i++) ctx.lineTo(x0 + i * step, yOf(data[i]));
					ctx.strokeStyle = col;
					ctx.lineWidth = 1.5;
					ctx.lineJoin = "round";
					ctx.stroke();
					if (!fill) return;
					ctx.lineTo(width, height);
					ctx.lineTo(x0, height);
					ctx.closePath();
					const g = ctx.createLinearGradient(0, 0, 0, height);
					g.addColorStop(0, Qt.alpha(col, 0.35));
					g.addColorStop(1, Qt.alpha(col, 0));
					ctx.fillStyle = g;
					ctx.fill();
				};
				draw(graph.series, graph.lineColor, true);
				draw(graph.series2, graph.line2Color, false);
			}

			Connections {
				target: graph
				function onSeriesChanged() { canvas.requestPaint(); }
				function onLineColorChanged() { canvas.requestPaint(); }
			}
		}
	}

	ColumnLayout {
		id: column

		anchors.fill: parent
		anchors.margins: Config.inset
		spacing: 10

		Graph {
			icon: Config.icons.cpu
			title: "CPU"
			value: (SysStats.cpu[SysStats.cpu.length - 1] ?? 0) + "%"
			series: SysStats.cpu
		}

		Graph {
			icon: Config.icons.ram
			title: "Memory"
			value: (SysStats.mem[SysStats.mem.length - 1] ?? 0) + "%"
			series: SysStats.mem
			lineColor: Config.green
		}

		Graph {
			icon: Config.icons.wifi
			title: "Network"
			value: Config.icons.down + " " + SysStats.human(SysStats.down[SysStats.down.length - 1] ?? 0)
				+ "/s  " + Config.icons.up + " " + SysStats.human(SysStats.up[SysStats.up.length - 1] ?? 0) + "/s"
			series: SysStats.down
			series2: SysStats.up
			max: 0
			lineColor: Config.yellow
		}
	}
}
