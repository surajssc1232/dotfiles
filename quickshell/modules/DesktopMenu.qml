import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Right-click menu for the desktop and its icons.
//
// Its own overlay surface rather than part of the wallpaper layer, which sits
// under every window: a menu opened near one would be drawn behind it. Mapped
// only while open; a click anywhere off the card closes it, as in the
// launcher's menu.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property var item: Desktop.menuItem
	readonly property bool isApp: root.item?.kind === "app"
	readonly property bool isFile: (root.item?.path ?? "") !== ""

	visible: Desktop.menuOpen && Desktop.menuScreen === (modelData?.name ?? "")

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
	WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell-desktop-menu"

	onVisibleChanged: if (visible) keys.forceActiveFocus()

	function entries(): var {
		const it = root.item;
		if (!it) {
			return [
				{ label: "Open launcher", glyph: Config.icons.apps, run: () => Launcher.show("") },
				{ label: "Sort icons by name", glyph: Config.icons.sort,
					run: () => Desktop.sortByName() },
				{ label: "Open Desktop folder", glyph: "",
					run: () => FileSearch.open(Desktop.folder) },
				{ label: "Terminal here", glyph: Config.icons.terminal,
					run: () => Launcher.detach(Config.terminal.slice(), Desktop.folder) },
				{ label: (Desktop.showFiles ? "Hide" : "Show") + " files from ~/Desktop", glyph: Config.icons.inbox,
					run: () => Desktop.setShowFiles(!Desktop.showFiles) },
				{ label: "Hide desktop icons", glyph: Config.icons.toggleOff,
					run: () => Desktop.setEnabled(false) }
			];
		}

		const out = [{ label: "Open", glyph: Config.icons.arrowRight, bold: true, run: () => Desktop.open(it) }];

		// "New Window", "New Private Window" and the like, straight from the icon.
		if (root.isApp && it.entry) {
			for (const a of (it.entry.actions ?? [])) {
				const action = a;
				out.push({ label: action.name, glyph: Config.icons.arrowRight,
					run: () => Launcher.launch(it.entry, action) });
			}
		}

		if (root.isFile) {
			out.push({ label: "Show in folder", glyph: Config.icons.inbox, run: () => FileSearch.reveal(it.path) });
			out.push({ label: "Copy path", glyph: Config.icons.clipboard, run: () => Clipboard.copy(it.path) });
			out.push({ label: "Move to trash", glyph: Config.icons.trash, danger: true, run: () => Desktop.trash(it) });
		} else {
			out.push({ label: "Remove from desktop", glyph: Config.icons.close, danger: true,
				run: () => Desktop.remove(it.id) });
		}
		return out;
	}

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.AllButtons
		onPressed: Desktop.closeMenu()
	}

	Panel {
		id: card

		readonly property var items: root.visible ? root.entries() : []
		readonly property int headerHeight: root.item ? 30 : 0

		width: 240
		height: items.length * 30 + headerHeight + Config.padding * 2

		x: Math.max(8, Math.min(root.width - width - 8, Desktop.menuAt.x))
		y: Math.max(8, Math.min(root.height - height - 8, Desktop.menuAt.y))

		transformOrigin: Item.TopLeft
		scale: root.visible ? 1 : 0.92
		Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

		FocusScope {
			id: keys

			anchors.fill: parent
			Keys.onEscapePressed: Desktop.closeMenu()

			Column {
				anchors.fill: parent
				anchors.margins: Config.padding

				// The icon's name, so it is clear which one the menu is about.
				Label {
					visible: root.item !== null
					width: parent.width
					height: card.headerHeight
					leftPadding: 8
					verticalAlignment: Text.AlignVCenter
					text: root.item?.name ?? ""
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
					elide: Text.ElideRight
				}

				Repeater {
					model: card.items

					delegate: MouseArea {
						id: entry

						required property var modelData

						width: parent.width
						height: 30
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor

						onClicked: {
							const run = entry.modelData.run;
							Desktop.closeMenu();
							run();
						}

						Rectangle {
							anchors.fill: parent
							radius: Config.radius - 4
							color: entry.containsMouse ? Config.bgAlt : "transparent"
						}

						Row {
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 8
							spacing: 10

							Label {
								width: 16
								text: entry.modelData.glyph ?? ""
								color: entry.modelData.danger ? Config.red : Config.fgDim
								font.pixelSize: Config.fontSize
							}

							Label {
								text: entry.modelData.label
								color: entry.modelData.danger ? Config.red : Config.fg
								font.pixelSize: Config.fontSize - 1
								font.weight: entry.modelData.bold ? Font.DemiBold : Font.Normal
							}
						}
					}
				}
			}
		}
	}
}
