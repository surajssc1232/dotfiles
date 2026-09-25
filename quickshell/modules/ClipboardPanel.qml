import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Clipboard history, in the shape Windows put on Super+V: a narrow card of
// entries, each its own tile with a pin in the corner.
//
// Holds the keyboard exclusively while it is up, like the launcher: every key
// is handled here rather than going back to the compositor first.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property int cardWidth: 620
	readonly property int textTile: 84
	readonly property int imageTile: 128
	readonly property int headerHeight: 30
	readonly property int searchHeight: 32
	readonly property int footerHeight: 22
	readonly property int maxListHeight: 460

	// Tiles are not all the same height, so the list is capped in pixels.
	readonly property int sectionHeight: 22

	readonly property int tilesHeight: {
		let total = 0;
		let group = "";
		for (const row of Clipboard.rows) {
			if (row.group !== group) {
				total += root.sectionHeight;
				group = row.group;
			}
			total += (row.kind === "image" ? root.imageTile : root.textTile) + 6;
		}
		return total;
	}

	readonly property bool empty: Clipboard.rows.length === 0

	// The list and the empty notice occupy the same space rather than
	// stacking: with both claiming height the card overflowed and the hints
	// ended up painted below it.
	readonly property int bodyHeight: root.empty
		? root.textTile
		: Math.min(root.tilesHeight, root.maxListHeight)

	readonly property int listHeight: root.bodyHeight

	visible: Clipboard.shown

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
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-clipboard"

	onVisibleChanged: if (root.visible) field.forceActiveFocus()

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		onPressed: Clipboard.hide()
	}

	Rectangle {
		id: card

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		anchors.topMargin: Math.round(parent.height * 0.12)

		width: root.cardWidth
		height: root.headerHeight + root.searchHeight + root.bodyHeight
			+ root.footerHeight + Config.padding

		radius: Config.radius
		color: Config.bg
		border.width: 1
		border.color: Config.border

		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.AllButtons
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Config.padding / 2
			spacing: 0

			// ---- title ----
			RowLayout {
				Layout.fillWidth: true
				Layout.preferredHeight: root.headerHeight
				Layout.leftMargin: 10
				Layout.rightMargin: 8
				spacing: 6

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: "Clipboard"
					color: Config.accent
					elide: Text.ElideRight
				}

				Label {
					text: Clipboard.rows.length
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}
			}

			// ---- search ----
			Rectangle {
				Layout.fillWidth: true
				Layout.leftMargin: 8
				Layout.rightMargin: 8
				Layout.preferredHeight: root.searchHeight - 6

				radius: Config.radius - 4
				color: Config.bgAlt

				TextInput {
					id: field

					anchors.fill: parent
					anchors.leftMargin: 10
					anchors.rightMargin: 10

					verticalAlignment: TextInput.AlignVCenter
					color: Config.fg
					font.family: Config.font
					font.pixelSize: Config.fontSize - 1
					selectByMouse: true
					selectionColor: Config.accent
					clip: true

					text: Clipboard.query
					onTextChanged: {
						Clipboard.query = text;
						Clipboard.index = 0;
					}

					Keys.onEscapePressed: Clipboard.hide()
					Keys.onReturnPressed: Clipboard.activate()
					Keys.onEnterPressed: Clipboard.activate()
					Keys.onDownPressed: Clipboard.move(1)
					Keys.onUpPressed: Clipboard.move(-1)
					Keys.onDeletePressed: Clipboard.removeSelected()

					Keys.onPressed: event => {
						if (!(event.modifiers & Qt.ControlModifier)) return;

						if (event.key === Qt.Key_N) {
							Clipboard.move(1);
							event.accepted = true;
						} else if (event.key === Qt.Key_P) {
							Clipboard.move(-1);
							event.accepted = true;
						} else if (event.key === Qt.Key_D) {
							Clipboard.togglePin(Clipboard.selected);
							event.accepted = true;
						} else if (event.key === Qt.Key_Delete
								&& (event.modifiers & Qt.ShiftModifier)) {
							// Deliberately a three-key chord: this throws away
							// everything that is not pinned, and the button
							// that used to do it was one stray click away from
							// the search field.
							Clipboard.clearHistory();
							event.accepted = true;
						}
					}

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: "Search"
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 2
						visible: !field.text
					}
				}
			}

			// ---- entries ----
			ListView {
				id: list

				Layout.fillWidth: true
				Layout.preferredHeight: root.empty ? 0 : root.listHeight
				Layout.topMargin: 6

				model: Clipboard.rows
				currentIndex: Clipboard.index
				spacing: 6
				clip: true
				visible: !root.empty
				boundsBehavior: Flickable.StopAtBounds
				onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

				// Only ever "Pinned" and "Recent", and the header for the
				// first group is skipped when nothing is pinned.
				section.property: "group"
				section.criteria: ViewSection.FullString
				section.delegate: Item {
					required property string section

					width: ListView.view.width
					height: root.sectionHeight

					Label {
						anchors.left: parent.left
						anchors.leftMargin: 12
						anchors.verticalCenter: parent.verticalCenter
						text: parent.section
						color: parent.section === "Pinned" ? Config.accent : Config.fgDim
						font.pixelSize: Config.fontSize - 4
					}

					Rectangle {
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						anchors.leftMargin: 66
						anchors.rightMargin: 12
						height: 1
						color: Config.border
					}
				}

				delegate: Rectangle {
					id: tile

					required property var modelData
					required property int index

					readonly property bool current: tile.index === Clipboard.index

					width: Math.max(0, ListView.view.width - 16)
					x: 8
					height: tile.modelData.kind === "image"
						? root.imageTile : root.textTile

					radius: Config.radius - 2
					color: tile.current || hover.containsMouse ? Config.bgAlt
						: Qt.darker(Config.bgAlt, 1.25)
					border.width: tile.current ? 1 : 0
					border.color: Config.accent

					MouseArea {
						id: hover

						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							Clipboard.index = tile.index;
							Clipboard.activate();
						}
					}

					// ---- what was copied ----
					Label {
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.top: parent.top
						anchors.leftMargin: 12
						anchors.rightMargin: 12
						anchors.topMargin: 10

						visible: tile.modelData.kind !== "image"
						text: tile.modelData.kind === "image"
							? "" : tile.modelData.text
						color: Config.fg
						font.pixelSize: Config.fontSize - 1
						wrapMode: Text.Wrap
						maximumLineCount: 2
						elide: Text.ElideRight
						textFormat: Text.PlainText
					}

					Image {
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.top: parent.top
						anchors.leftMargin: 12
						anchors.rightMargin: 12
						anchors.topMargin: 10
						height: parent.height - 42

						visible: tile.modelData.kind === "image"
						source: tile.modelData.kind === "image"
							? "file://" + tile.modelData.path : ""
						fillMode: Image.PreserveAspectFit
						horizontalAlignment: Image.AlignLeft
						asynchronous: true
						sourceSize.width: 740
						sourceSize.height: 180
					}

					// ---- the corner ----
					Label {
						anchors.left: parent.left
						anchors.bottom: parent.bottom
						anchors.leftMargin: 12
						anchors.bottomMargin: 8

						text: tile.modelData.kind === "image"
							? Qt.formatDateTime(new Date(tile.modelData.at), "d MMM hh:mm")
							: Clipboard.describe(tile.modelData.text)
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 4
					}

					MouseArea {
						id: pin

						anchors.right: parent.right
						anchors.bottom: parent.bottom
						anchors.rightMargin: 8
						anchors.bottomMargin: 4

						width: 24
						height: 22

						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Clipboard.togglePin(tile.modelData)

						Label {
							anchors.centerIn: parent
							text: Config.icons.pin
							color: tile.modelData.pinned ? Config.accent
								: pin.containsMouse ? Config.fg : Config.fgDim
							font.pixelSize: Config.fontSize - 3
							// A pinned entry reads as held down rather than
							// merely coloured differently.
							rotation: tile.modelData.pinned ? 0 : -35
						}
					}
				}
			}

			// ---- nothing here ----
			Label {
				Layout.fillWidth: true
				Layout.preferredHeight: root.empty ? root.textTile : 0

				visible: root.empty
				text: Clipboard.query ? "Nothing matches" : "Nothing copied yet"
				color: Config.fgDim
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
			}

			// ---- hints ----
			// One elidable line: five separate labels added up to more than
			// the card is wide, and a child that wide forces the layout wider
			// than the card it sits in — which is what pushed the tiles and
			// the count out past the right edge.
			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				Layout.preferredHeight: root.footerHeight
				Layout.leftMargin: 12
				Layout.rightMargin: 12

				text: "enter copies · ctrl+d pins · del removes · ctrl+shift+del clears"
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 4
				elide: Text.ElideRight
				verticalAlignment: Text.AlignVCenter
			}
		}
	}
}
