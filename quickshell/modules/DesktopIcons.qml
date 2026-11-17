import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

// Desktop icons, drawn on the wallpaper layer: under every window, over the
// picture. Laid out on a grid the way Windows does it — down the left edge
// first, then the next column — and each icon remembers the cell it was
// dragged to. See services/Desktop.qml for what is on it.
Item {
	id: root

	// The screen's name, for the context menu to open on the right output.
	property string screenName: ""

	readonly property int cellW: 92
	readonly property int cellH: 100
	readonly property int iconSize: 48

	// Somewhere icons must not go (the graphs card), in this item's coordinates.
	property rect avoid: Qt.rect(0, 0, 0, 0)

	function blocked(c: int, r: int): bool {
		const a = root.avoid;
		if (a.width <= 0 || a.height <= 0) return false;
		const x = c * root.cellW, y = r * root.cellH;
		return x < a.x + a.width && x + root.cellW > a.x
			&& y < a.y + a.height && y + root.cellH > a.y;
	}

	readonly property int cols: Math.max(1, Math.floor(width / cellW))
	readonly property int rows: Math.max(1, Math.floor(height / cellH))

	// Every icon's cell, { key: { c, r } }: remembered cells first, as long as
	// they are on this screen and not taken; the rest fill the gaps in order.
	readonly property var cells: {
		const out = ({});
		const used = ({});
		const pos = Desktop.positions;
		const items = Desktop.items;

		for (const it of items) {
			const p = pos[it.key];
			if (!p || p.c >= root.cols || p.r >= root.rows || root.blocked(p.c, p.r)) continue;
			const k = p.c + "," + p.r;
			if (used[k]) continue;
			used[k] = true;
			out[it.key] = { c: p.c, r: p.r };
		}

		let n = 0;
		const last = root.cols * root.rows - 1;
		for (const it of items) {
			if (out[it.key]) continue;
			while (n < last && (used[Math.floor(n / root.rows) + "," + (n % root.rows)]
				|| root.blocked(Math.floor(n / root.rows), n % root.rows))) n++;
			const c = Math.floor(n / root.rows), r = n % root.rows;
			used[c + "," + r] = true;
			out[it.key] = { c: c, r: r };
		}
		return out;
	}

	visible: Desktop.enabled

	// Empty desktop: a click clears the selection, a right-click opens the
	// desktop's own menu.
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		onPressed: mouse => {
			Desktop.selected = "";
			if (mouse.button === Qt.RightButton)
				Desktop.openMenu(null, root.screenName, root.mapToItem(null, mouse.x, mouse.y));
		}
	}

	Repeater {
		model: Desktop.items

		delegate: MouseArea {
			id: icon

			required property var modelData

			readonly property var cell: root.cells[modelData.key] ?? { c: 0, r: 0 }
			readonly property bool selected: Desktop.selected === modelData.key
			readonly property string iconPath: Launcher.icon(modelData.iconName)

			// How far the icon has been dragged from its cell.
			property real dx: 0
			property real dy: 0
			property point pressedAt: Qt.point(0, 0)
			property bool dragging: false

			x: cell.c * root.cellW + dx
			y: cell.r * root.cellH + dy
			z: dragging ? 10 : selected ? 5 : 0
			width: root.cellW
			height: root.cellH

			hoverEnabled: true
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

			// Snaps into its new cell rather than jumping there.
			Behavior on x { enabled: !icon.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
			Behavior on y { enabled: !icon.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

			onPressed: mouse => {
				Desktop.selected = modelData.key;
				icon.pressedAt = icon.mapToItem(root, mouse.x, mouse.y);
				if (mouse.button === Qt.RightButton)
					Desktop.openMenu(modelData, root.screenName, icon.mapToItem(null, mouse.x, mouse.y));
			}

			// Measured against the desktop, not the icon: the icon is what moves.
			onPositionChanged: mouse => {
				if (!(icon.pressedButtons & Qt.LeftButton)) return;
				const at = icon.mapToItem(root, mouse.x, mouse.y);
				const mx = at.x - icon.pressedAt.x;
				const my = at.y - icon.pressedAt.y;
				if (!icon.dragging && Math.abs(mx) + Math.abs(my) < 8) return;
				icon.dragging = true;
				icon.dx = mx;
				icon.dy = my;
			}

			onReleased: {
				if (!icon.dragging) return;
				const c = Math.max(0, Math.min(root.cols - 1,
					Math.round((icon.cell.c * root.cellW + icon.dx) / root.cellW)));
				const r = Math.max(0, Math.min(root.rows - 1,
					Math.round((icon.cell.r * root.cellH + icon.dy) / root.cellH)));
				icon.dragging = false;
				// Dropped on the graphs: back where it came from.
				if (!root.blocked(c, r)) Desktop.move(modelData.key, c, r, root.cells);
				icon.dx = 0;
				icon.dy = 0;
			}

			onCanceled: {
				icon.dragging = false;
				icon.dx = 0;
				icon.dy = 0;
			}

			onDoubleClicked: mouse => {
				if (mouse.button === Qt.LeftButton) Desktop.open(modelData);
			}

			Rectangle {
				anchors.fill: parent
				anchors.margins: 3
				radius: Config.radius - 2
				color: icon.selected ? Qt.alpha(Config.accent, 0.28)
					: icon.containsMouse ? Qt.alpha(Config.fg, 0.10) : "transparent"
				border.width: icon.selected ? 1 : 0
				border.color: Qt.alpha(Config.accent, 0.7)
				opacity: icon.dragging ? 0.6 : 1

				Behavior on color { ColorAnimation { duration: Config.animFast } }
			}

			Item {
				id: picture

				anchors.horizontalCenter: parent.horizontalCenter
				anchors.top: parent.top
				anchors.topMargin: 10
				width: root.iconSize
				height: root.iconSize
				scale: icon.pressed && !icon.dragging ? 0.92 : 1

				Behavior on scale { NumberAnimation { duration: 90 } }

				// A picture on the desktop shows itself.
				Image {
					anchors.fill: parent
					visible: icon.modelData.image
					source: icon.modelData.image ? "file://" + icon.modelData.path : ""
					fillMode: Image.PreserveAspectFit
					asynchronous: true
					sourceSize.width: root.iconSize * 2
					sourceSize.height: root.iconSize * 2
				}

				IconImage {
					anchors.fill: parent
					visible: !icon.modelData.image && icon.iconPath !== ""
					source: icon.iconPath
					asynchronous: true
				}

				// No themed icon to be found: the font's glyph stands in.
				Text {
					anchors.centerIn: parent
					visible: !icon.modelData.image && icon.iconPath === ""
					text: icon.modelData.kind === "app" ? Config.icons.apps
						: icon.modelData.isDir ? "" : ""
					color: Config.fg
					font.family: Config.font
					font.pixelSize: root.iconSize - 10
				}
			}

			// Light text on a dark halo, readable on any wallpaper.
			Text {
				id: caption

				anchors.top: picture.bottom
				anchors.topMargin: 6
				anchors.horizontalCenter: parent.horizontalCenter
				width: parent.width - 10
				horizontalAlignment: Text.AlignHCenter
				text: icon.modelData.name
				color: "white"
				font.family: Config.font
				font.pixelSize: Config.fontSize - 2
				wrapMode: Text.Wrap
				maximumLineCount: icon.selected ? 3 : 2
				elide: Text.ElideRight
				style: Text.Outline
				styleColor: Qt.rgba(0, 0, 0, 0.55)
			}
		}
	}
}
