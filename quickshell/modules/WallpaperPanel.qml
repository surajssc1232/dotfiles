import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// Wallpaper picker, shown as the Wallpaper tile's detail pane.
Item {
	id: root

	property bool active: false

	// Which picture the grid is choosing: the desktop's, or the lock screen's.
	property string mode: "desktop"

	readonly property bool lockMode: root.mode === "lock"

	// What the tick is drawn on. In lock mode with nothing chosen this is empty
	// on purpose — no tile is "the" lock wallpaper, because the lock screen is
	// simply following the desktop.
	readonly property string selected: root.lockMode ? Wallpaper.lock : Wallpaper.current

	// Leaving the pane resets it, so reopening it lands on the desktop grid
	// rather than wherever it was left days ago.
	onActiveChanged: if (!active) root.mode = "desktop"

	readonly property int columns: 2
	readonly property int spacing: 6

	// GridView counts the gap as part of the cell, so the cell is the full
	// share of the width and the thumbnail inside it is that minus the gap.
	// Sizing the thumbnail first and adding the gap afterwards overflows the
	// pane by exactly one gap and drops the grid to a single column.
	readonly property int cellWidth: Math.floor(width / columns)
	readonly property int tileWidth: cellWidth - spacing
	readonly property int tileHeight: Math.round(tileWidth * 9 / 16)
	readonly property int cellHeight: tileHeight + spacing
	readonly property int maxRows: 2

	implicitHeight: body.implicitHeight

	ColumnLayout {
		id: body

		anchors.fill: parent
		spacing: 4

		// One grid, two destinations: which one a click sets is chosen here
		// rather than by duplicating the whole picker.
		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 24
			Layout.leftMargin: 2
			spacing: 4

			Segment {
				text: "Desktop"
				active: !root.lockMode
				onTriggered: root.mode = "desktop"
			}

			Segment {
				text: "Lock screen"
				active: root.lockMode
				onTriggered: root.mode = "lock"
			}

			Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

			Label {
				// Says where these came from, since the folder is not obvious
				// from a grid of pictures.
				text: "~/Downloads · " + Wallpaper.count
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 4
				elide: Text.ElideRight
			}
		}

		// Only in lock mode, and only worth a row because it says something the
		// ticks cannot: that no tile is chosen, and why.
		RowLayout {
			Layout.fillWidth: true
			Layout.leftMargin: 4
			Layout.rightMargin: 2
			spacing: 6
			visible: root.lockMode

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: Wallpaper.lock
					? Wallpaper.lock.split("/").pop()
					: "Following the desktop wallpaper"
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				elide: Text.ElideMiddle
			}

			Segment {
				text: "Match desktop"
				visible: Wallpaper.lock !== ""
				onTriggered: Wallpaper.clearLock()
			}
		}

		Label {
			Layout.fillWidth: true
			Layout.preferredHeight: 40
			visible: Wallpaper.count === 0
			text: "No images in ~/Downloads"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 1
			horizontalAlignment: Text.AlignHCenter
			verticalAlignment: Text.AlignVCenter
		}

		GridView {
			id: grid

			Layout.fillWidth: true
			Layout.preferredHeight: Math.min(
				Math.ceil(Wallpaper.count / root.columns) * root.cellHeight,
				root.maxRows * root.cellHeight)

			visible: Wallpaper.count > 0
			clip: true
			model: Wallpaper.model
			cellWidth: root.cellWidth
			cellHeight: root.cellHeight
			boundsBehavior: Flickable.StopAtBounds
			// Nothing here changes as you scroll, so recycling is free.
			reuseItems: true

			// Wheel is handled explicitly rather than left to the Flickable.
			// Every cell is a MouseArea, and relying on the event falling
			// through all of them to the view underneath is what left the grid
			// unscrollable. A handler sees the wheel first and accepts it, so
			// the view never gets a second go at the same notch.
			WheelHandler {
				acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

				onWheel: event => {
					const max = Math.max(0, grid.contentHeight - grid.height);
					grid.contentY = Math.max(0, Math.min(max,
						grid.contentY - event.pixelDelta.y
						- event.angleDelta.y / 120 * root.cellHeight));
				}
			}

			delegate: MouseArea {
				id: cell

				required property int index
				required property string filePath
				required property string fileName

				readonly property bool current: filePath === root.selected

				width: root.tileWidth
				height: root.tileHeight

				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.lockMode
					? Wallpaper.setLock(cell.filePath)
					: Wallpaper.set(cell.filePath)

				Rectangle {
					anchors.fill: parent
					radius: Config.radius - 2
					color: Config.bgAlt
					clip: true

					Image {
						id: preview

						anchors.fill: parent

						source: "file://" + cell.filePath
						fillMode: Image.PreserveAspectCrop
						// Decoded at roughly twice the cell so it stays sharp,
						// but nowhere near full size — these are multi-megabyte
						// photographs and decoding them whole for a thumbnail
						// would stall the panel every time it opens.
						sourceSize.width: root.tileWidth * 2
						asynchronous: true
						cache: true
					}

					Label {
						anchors.centerIn: parent
						visible: preview.status !== Image.Ready
						text: preview.status === Image.Error
							? Config.icons.warning
							: Config.icons.spinner
						color: Config.fgDim
						font.pixelSize: Config.fontSize
					}

					// Name only while pointed at: a caption under every tile
					// would compete with the pictures.
					Rectangle {
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: parent.bottom
						height: caption.implicitHeight + 6

						color: Qt.rgba(0, 0, 0, 0.65)
						visible: cell.containsMouse

						Label {
							id: caption

							anchors.fill: parent
							anchors.leftMargin: 6
							anchors.rightMargin: 6

							text: cell.fileName
							color: "#ffffff"
							font.pixelSize: Config.fontSize - 4
							verticalAlignment: Text.AlignVCenter
							elide: Text.ElideMiddle
						}
					}
				}

				// Selection ring drawn over the image rather than around it, so
				// picking a wallpaper never nudges the grid.
				Rectangle {
					anchors.fill: parent
					radius: Config.radius - 2
					color: "transparent"
					border.width: cell.current ? 2 : (cell.containsMouse ? 1 : 0)
					border.color: cell.current ? Config.accent : Config.fg
				}

				Rectangle {
					anchors.top: parent.top
					anchors.right: parent.right
					anchors.margins: 4

					width: 18
					height: 18
					radius: 9
					color: Config.accent
					visible: cell.current

					Label {
						anchors.centerIn: parent
						text: Config.icons.check
						color: Config.bg
						font.pixelSize: Config.fontSize - 5
					}
				}
			}
		}
	}

	// Small pill button: the destination switch, and the reset beside it.
	component Segment: MouseArea {
		id: seg

		property string text: ""
		property bool active: false
		signal triggered()

		implicitWidth: caption.implicitWidth + 18
		implicitHeight: 22
		Layout.preferredWidth: implicitWidth
		Layout.preferredHeight: implicitHeight

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: seg.triggered()

		Rectangle {
			anchors.fill: parent
			radius: height / 2
			color: seg.active ? Config.accent
				: seg.containsMouse ? Config.bgAlt
				: "transparent"
			border.width: seg.active ? 0 : 1
			border.color: Config.border
		}

		Label {
			id: caption

			anchors.centerIn: parent
			text: seg.text
			color: seg.active ? Config.bg
				: seg.containsMouse ? Config.fg
				: Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}
	}
}
