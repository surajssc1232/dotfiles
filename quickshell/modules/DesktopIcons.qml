import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

// Desktop icons, drawn on the wallpaper layer: under every window, over the
// picture. Laid out on a grid the way Windows does it — down the left edge
// first, then the next column — and each icon remembers the cell it was
// dragged to. See services/Desktop.qml for what is on it.
//
// Selecting works as on Windows: click for one, Ctrl+click to add or take
// away, drag across empty desktop for a box. Dragging any selected icon
// carries the whole selection with it.
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

	// ---- dragging the selection ----
	// One offset for every selected icon, so they move as a group.
	property bool dragging: false
	property real dragDx: 0
	property real dragDy: 0

	function drop() {
		const dc = Math.round(root.dragDx / root.cellW);
		const dr = Math.round(root.dragDy / root.cellH);
		root.dragging = false;
		Desktop.moveMany(Desktop.selectedKeys, dc, dr, root.cells, root.cols, root.rows,
			(c, r) => root.blocked(c, r));
		root.dragDx = 0;
		root.dragDy = 0;
	}

	// ---- box selection ----
	property bool banding: false
	property point bandFrom: Qt.point(0, 0)
	property point bandTo: Qt.point(0, 0)
	// What was selected before a Ctrl+drag box, which the box adds to.
	property var bandBase: []

	readonly property rect band: Qt.rect(
		Math.min(bandFrom.x, bandTo.x), Math.min(bandFrom.y, bandTo.y),
		Math.abs(bandTo.x - bandFrom.x), Math.abs(bandTo.y - bandFrom.y))

	// Icons whose picture or name the box touches, not merely their cell.
	function underBand(): var {
		const b = root.band;
		const hits = [];
		for (const it of Desktop.items) {
			const cell = root.cells[it.key];
			if (!cell) continue;
			const x = cell.c * root.cellW + 8, y = cell.r * root.cellH + 6;
			if (x < b.x + b.width && x + root.cellW - 16 > b.x
				&& y < b.y + b.height && y + root.cellH - 12 > b.y)
				hits.push(it.key);
		}
		return hits;
	}

	visible: Desktop.enabled

	// Empty desktop: a click clears the selection, a drag draws a box, a
	// right-click opens the desktop's own menu.
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton

		onPressed: mouse => {
			if (mouse.button === Qt.RightButton) {
				Desktop.clearSelection();
				Desktop.openMenu(null, root.screenName, mapToItem(null, mouse.x, mouse.y));
				return;
			}
			const ctrl = (mouse.modifiers & Qt.ControlModifier) !== 0;
			root.bandBase = ctrl ? Desktop.selectedKeys.slice() : [];
			if (!ctrl) Desktop.clearSelection();
			root.bandFrom = Qt.point(mouse.x, mouse.y);
			root.bandTo = root.bandFrom;
		}

		onPositionChanged: mouse => {
			if (!(pressedButtons & Qt.LeftButton)) return;
			root.bandTo = Qt.point(Math.max(0, Math.min(root.width, mouse.x)),
				Math.max(0, Math.min(root.height, mouse.y)));
			if (!root.banding && root.band.width + root.band.height < 6) return;
			root.banding = true;
			const keys = root.bandBase.slice();
			for (const k of root.underBand()) if (keys.indexOf(k) === -1) keys.push(k);
			Desktop.select(keys);
		}

		onReleased: root.banding = false
		onCanceled: root.banding = false
	}

	Rectangle {
		visible: root.banding
		x: root.band.x
		y: root.band.y
		width: root.band.width
		height: root.band.height
		z: 20
		color: Qt.alpha(Config.accent, 0.18)
		border.width: 1
		border.color: Qt.alpha(Config.accent, 0.75)
	}

	Repeater {
		model: Desktop.items

		delegate: MouseArea {
			id: icon

			required property var modelData

			readonly property var cell: root.cells[modelData.key] ?? { c: 0, r: 0 }
			readonly property bool selected: Desktop.isSelected(modelData.key)
			readonly property bool carried: root.dragging && selected
			readonly property string iconPath: Launcher.icon(modelData.iconName)

			property point pressedAt: Qt.point(0, 0)
			property bool ctrlPress: false
			property bool moved: false

			x: cell.c * root.cellW + (carried ? root.dragDx : 0)
			y: cell.r * root.cellH + (carried ? root.dragDy : 0)
			z: carried ? 10 : selected ? 5 : 0
			width: root.cellW
			height: root.cellH

			hoverEnabled: true
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

			// Snaps into its new cell rather than jumping there.
			Behavior on x { enabled: !icon.carried; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
			Behavior on y { enabled: !icon.carried; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

			onPressed: mouse => {
				const key = modelData.key;
				icon.moved = false;
				icon.ctrlPress = (mouse.modifiers & Qt.ControlModifier) !== 0;
				icon.pressedAt = icon.mapToItem(root, mouse.x, mouse.y);

				if (mouse.button === Qt.RightButton) {
					// On a selected icon the menu is for the whole selection.
					if (!icon.selected) Desktop.select([key]);
					Desktop.openMenu(modelData, root.screenName, icon.mapToItem(null, mouse.x, mouse.y));
					return;
				}
				// Pressing an unselected icon picks it alone; a selected one
				// keeps the selection, so it can be dragged as a group. Ctrl
				// decides on release, once it is clear this was not a drag.
				if (!icon.selected && !icon.ctrlPress) Desktop.select([key]);
			}

			// Measured against the desktop, not the icon: the icon is what moves.
			onPositionChanged: mouse => {
				if (!(icon.pressedButtons & Qt.LeftButton)) return;
				const at = icon.mapToItem(root, mouse.x, mouse.y);
				const mx = at.x - icon.pressedAt.x;
				const my = at.y - icon.pressedAt.y;
				if (!root.dragging && Math.abs(mx) + Math.abs(my) < 8) return;
				if (!root.dragging) {
					// Ctrl+dragging an unselected icon brings it along too.
					if (!icon.selected) {
						if (icon.ctrlPress) Desktop.toggleSelected(modelData.key);
						else Desktop.select([modelData.key]);
					}
					root.dragging = true;
				}
				icon.moved = true;
				root.dragDx = mx;
				root.dragDy = my;
			}

			onReleased: mouse => {
				if (mouse.button !== Qt.LeftButton) return;
				if (root.dragging) {
					root.drop();
					return;
				}
				if (icon.moved) return;
				if (icon.ctrlPress) Desktop.toggleSelected(modelData.key);
				else Desktop.select([modelData.key]);
			}

			onCanceled: {
				root.dragging = false;
				root.dragDx = 0;
				root.dragDy = 0;
			}

			onDoubleClicked: mouse => {
				if (mouse.button === Qt.LeftButton && !icon.ctrlPress) Desktop.open(modelData);
			}

			Rectangle {
				anchors.fill: parent
				anchors.margins: 3
				radius: Config.radius - 2
				color: icon.selected ? Qt.alpha(Config.accent, 0.30)
					: icon.containsMouse && !root.dragging ? Qt.alpha("white", 0.14) : "transparent"
				border.width: icon.selected || (icon.containsMouse && !root.dragging) ? 1 : 0
				border.color: icon.selected ? Qt.alpha(Config.accent, 0.8) : Qt.alpha("white", 0.22)
				opacity: icon.carried ? 0.7 : 1

				Behavior on color { ColorAnimation { duration: Config.animFast } }
			}

			Item {
				id: picture

				anchors.horizontalCenter: parent.horizontalCenter
				anchors.top: parent.top
				anchors.topMargin: 10
				width: root.iconSize
				height: root.iconSize
				scale: icon.pressed && !root.dragging ? 0.94 : 1

				Behavior on scale { NumberAnimation { duration: 90 } }

				// A picture on the desktop shows itself.
				Image {
					anchors.fill: parent
					visible: icon.modelData.image
					source: icon.modelData.image ? "file://" + icon.modelData.path : ""
					fillMode: Image.PreserveAspectFit
					asynchronous: true
					smooth: true
					mipmap: true
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
					color: "white"
					font.family: Config.font
					font.pixelSize: root.iconSize - 10
				}
			}

			// A proportional face and a soft shadow, as Windows draws them. The
			// shadow is a blurred black copy behind the text rather than a hard
			// outline (which is what made the names look jagged), and the text
			// itself is never layered, so it stays rendered at full resolution.
			Text {
				id: halo

				anchors.fill: caption
				anchors.topMargin: 1
				horizontalAlignment: caption.horizontalAlignment
				text: caption.text
				color: "black"
				font: caption.font
				wrapMode: caption.wrapMode
				maximumLineCount: caption.maximumLineCount
				elide: caption.elide

				layer.enabled: true
				layer.effect: MultiEffect {
					blurEnabled: true
					blur: 0.6
					blurMax: 8
					opacity: 0.95
				}
			}

			Text {
				id: caption

				anchors.top: picture.bottom
				anchors.topMargin: 5
				anchors.horizontalCenter: parent.horizontalCenter
				width: parent.width - 10
				horizontalAlignment: Text.AlignHCenter
				text: icon.modelData.name
				color: "white"
				font.family: "DejaVu Sans"
				font.pixelSize: 12
				renderType: Text.NativeRendering
				wrapMode: Text.Wrap
				maximumLineCount: icon.selected ? 3 : 2
				elide: Text.ElideRight
			}
		}
	}
}
