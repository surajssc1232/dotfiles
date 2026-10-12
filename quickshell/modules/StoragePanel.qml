import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Storage review, opened by clicking the CPU / memory / disk pill: how full
// the disk is, what in $HOME is junk that can go, the biggest files, and where
// the space sits. Nothing is removed without a second click.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property int cardWidth: 640
	readonly property int rowHeight: 46
	readonly property int listHeight: 380

	// The row whose "remove" has been clicked once.
	property string armedPath: ""
	property bool armedAll: false

	readonly property var kindColors: ({
		trash: Config.red, cache: Config.accent, dev: Config.blue,
		junk: Config.yellow, broken: Config.fgDim, build: Config.green
	})

	visible: Storage.shown

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}

	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	focusable: true
	// Stays open behind the launcher or clipboard: while one of them is up
	// this drops a layer and lets go of the keyboard, so they can have it.
	readonly property bool covered: Launcher.open || Clipboard.shown
	WlrLayershell.layer: covered ? WlrLayer.Top : WlrLayer.Overlay
	WlrLayershell.keyboardFocus: covered ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-storage"

	onCoveredChanged: if (!covered && visible) keys.forceActiveFocus()

	onVisibleChanged: {
		root.armedPath = "";
		root.armedAll = false;
		if (root.visible) keys.forceActiveFocus();
	}

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.AllButtons
		onPressed: Storage.hide()
	}

	Panel {
		id: card

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		anchors.topMargin: Math.round(parent.height * 0.1)
		width: root.cardWidth
		height: col.implicitHeight + Config.padding

		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.AllButtons
		}

		FocusScope {
			id: keys

			anchors.fill: parent
			Keys.onEscapePressed: Storage.hide()

			ColumnLayout {
				id: col

				anchors.left: parent.left
				anchors.right: parent.right
				anchors.top: parent.top
				anchors.margins: Config.padding / 2 + 4
				spacing: 8

				// ---- title and disk meter ----
				RowLayout {
					Layout.fillWidth: true
					Layout.topMargin: 4
					spacing: 8

					Label {
						text: "Storage"
						color: Config.accent
					}

					Label {
						Layout.fillWidth: true
						text: Storage.scanning ? "scanning…" : ""
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
					}

					Label {
						text: Storage.size(Storage.diskUsed) + " / " + Storage.size(Storage.diskTotal)
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 2
					}

					Label {
						text: Storage.diskPercent + "%"
						color: Storage.diskPercent > 90 ? Config.red
							: Storage.diskPercent > 75 ? Config.yellow : Config.accent
						font.pixelSize: Config.fontSize + 4
						font.weight: Font.DemiBold
					}

					Button2 {
						text: "rescan"
						tone: Config.fgDim
						onClicked: Storage.scan()
					}
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 6
					radius: 3
					color: Config.bgAlt

					Rectangle {
						width: parent.width * Storage.diskPercent / 100
						height: parent.height
						radius: 3
						color: Storage.diskPercent > 90 ? Config.red
							: Storage.diskPercent > 75 ? Config.yellow : Config.accent

						Behavior on width { NumberAnimation { duration: 300 } }
					}
				}

				// ---- tabs, and sorting ----
				RowLayout {
					Layout.fillWidth: true
					spacing: 6

					Tab { label: "Overview"; key: "overview" }
					Tab { label: "Junk"; key: "junk" }
					Tab { label: "Large files"; key: "large" }
					Tab { label: "Folders"; key: "folders" }

					Item { Layout.fillWidth: true }

					Label {
						text: "Sort"
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
					}

					SortTab { label: "Size"; key: "size" }
					SortTab { label: "Name"; key: "name" }
					SortTab { label: "Date"; key: "age" }
				}

				// ---- the clean-all line, on the junk tab ----
				RowLayout {
					Layout.fillWidth: true
					visible: Storage.tab === "junk"
					spacing: 8

					Label {
						Layout.fillWidth: true
						text: Storage.junkCount + " items can be removed · "
							+ Storage.size(Storage.junkBytes) + " to free"
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 2
					}

					Button2 {
						visible: !root.armedAll
						enabled: Storage.junkCount > 0
						text: "clean all"
						tone: Config.red
						onClicked: root.armedAll = true
					}

					Button2 {
						visible: root.armedAll
						text: "cancel"
						tone: Config.fgDim
						onClicked: root.armedAll = false
					}

					Button2 {
						visible: root.armedAll
						text: "yes, remove " + Storage.size(Storage.junkBytes)
						tone: Config.red
						onClicked: { Storage.cleanAll(); root.armedAll = false; }
					}
				}

				Label {
					Layout.fillWidth: true
					visible: Storage.tab === "large" || Storage.tab === "folders"
					text: Storage.tab === "large"
						? "Files over 100 MB in your home folder. Removal is permanent."
						: "Where the space in your home folder sits. Review only."
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
				}

				// ---- overview: graphs ----
				Item {
					Layout.fillWidth: true
					Layout.preferredHeight: root.listHeight
					visible: Storage.tab === "overview"

					readonly property real junk: Storage.junkBytes
					readonly property real used: Math.max(0, Storage.diskUsed - junk)
					readonly property real total: Math.max(1, Storage.diskTotal)

					RowLayout {
						anchors.fill: parent
						spacing: 20

						// Disk donut: kept, reclaimable, free.
						Item {
							Layout.preferredWidth: 170
							Layout.preferredHeight: 170
							Layout.alignment: Qt.AlignTop

							Canvas {
								id: donut

								anchors.fill: parent
								property real used: parent.parent.parent.used
								property real junk: parent.parent.parent.junk
								property real total: parent.parent.parent.total
								property color cUsed: Config.accent
								property color cJunk: Config.yellow
								property color cFree: Config.bgAlt

								onUsedChanged: requestPaint()
								onJunkChanged: requestPaint()
								onTotalChanged: requestPaint()
								onCUsedChanged: requestPaint()
								onCJunkChanged: requestPaint()
								onCFreeChanged: requestPaint()

								onPaint: {
									const ctx = getContext("2d");
									ctx.reset();
									const cx = width / 2, cy = height / 2;
									const r = Math.min(cx, cy) - 8;
									ctx.lineWidth = 16;
									ctx.lineCap = "butt";
									const parts = [[used, cUsed], [junk, cJunk], [total - used - junk, cFree]];
									let a = -Math.PI / 2;
									for (const [v, c] of parts) {
										const sweep = Math.max(0, v) / total * Math.PI * 2;
										if (sweep <= 0) continue;
										ctx.beginPath();
										ctx.arc(cx, cy, r, a, a + sweep);
										ctx.strokeStyle = c;
										ctx.stroke();
										a += sweep;
									}
								}
							}

							Column {
								anchors.centerIn: parent
								spacing: 0

								Label {
									anchors.horizontalCenter: parent.horizontalCenter
									text: Storage.diskPercent + "%"
									color: Config.fg
									font.pixelSize: Config.fontSize + 8
									font.weight: Font.DemiBold
								}

								Label {
									anchors.horizontalCenter: parent.horizontalCenter
									text: Storage.size(Math.max(0, Storage.diskTotal - Storage.diskUsed)) + " free"
									color: Config.fgDim
									font.pixelSize: Config.fontSize - 3
								}
							}
						}

						ColumnLayout {
							Layout.fillWidth: true
							Layout.fillHeight: true
							spacing: 6

							// Legend for the donut.
							Repeater {
								model: [
									{ name: "In use", bytes: parent.parent.parent.used, tone: Config.accent },
									{ name: "Can be removed", bytes: parent.parent.parent.junk, tone: Config.yellow },
									{ name: "Free", bytes: Math.max(0, Storage.diskTotal - Storage.diskUsed), tone: Config.fgDim }
								]

								RowLayout {
									required property var modelData

									Layout.fillWidth: true
									spacing: 8

									Rectangle {
										Layout.preferredWidth: 10
										Layout.preferredHeight: 10
										radius: 5
										color: modelData.tone
									}

									Label {
										Layout.fillWidth: true
										text: modelData.name
										font.pixelSize: Config.fontSize - 2
									}

									Label {
										text: Storage.size(modelData.bytes)
										color: Config.fgDim
										font.pixelSize: Config.fontSize - 2
									}
								}
							}

							Label {
								Layout.topMargin: 8
								text: "JUNK BY TYPE"
								color: Config.fgDim
								font.pixelSize: Config.fontSize - 4
								font.letterSpacing: 1
							}

							// One stacked bar, split by kind.
							Rectangle {
								Layout.fillWidth: true
								Layout.preferredHeight: 10
								radius: 5
								color: Config.bgAlt
								clip: true

								Row {
									anchors.fill: parent

									Repeater {
										model: Storage.kindTotals

										Rectangle {
											required property var modelData

											width: Storage.junkBytes > 0
												? parent.width * modelData.bytes / Storage.junkBytes : 0
											height: parent.height
											color: root.kindColors[modelData.kind] ?? Config.fgDim
										}
									}
								}
							}

							Flow {
								Layout.fillWidth: true
								spacing: 12

								Repeater {
									model: Storage.kindTotals

									Row {
										required property var modelData

										spacing: 5

										Rectangle {
											width: 8
											height: 8
											radius: 4
											anchors.verticalCenter: parent.verticalCenter
											color: root.kindColors[modelData.kind] ?? Config.fgDim
										}

										Label {
											text: (Storage.kindNames[modelData.kind] ?? modelData.kind)
												+ " " + Storage.size(modelData.bytes)
											color: Config.fgDim
											font.pixelSize: Config.fontSize - 4
										}
									}
								}
							}

							Label {
								Layout.topMargin: 8
								text: "LARGEST FOLDERS"
								color: Config.fgDim
								font.pixelSize: Config.fontSize - 4
								font.letterSpacing: 1
							}

							Repeater {
								model: Storage.topFolders

								RowLayout {
									required property var modelData

									Layout.fillWidth: true
									spacing: 8

									Label {
										Layout.preferredWidth: 110
										text: modelData.name
										elide: Text.ElideRight
										font.pixelSize: Config.fontSize - 3
									}

									Rectangle {
										Layout.fillWidth: true
										Layout.preferredHeight: 8
										radius: 4
										color: Config.bgAlt

										Rectangle {
											width: Storage.topFolders.length > 0 && Storage.topFolders[0].bytes > 0
												? parent.width * modelData.bytes / Storage.topFolders[0].bytes : 0
											height: parent.height
											radius: 4
											color: Config.blue
										}
									}

									Label {
										Layout.preferredWidth: 64
										horizontalAlignment: Text.AlignRight
										text: Storage.size(modelData.bytes)
										color: Config.fgDim
										font.pixelSize: Config.fontSize - 3
									}
								}
							}

							Item { Layout.fillHeight: true }
						}
					}
				}

				// ---- list ----
				ListView {
					id: list

					Layout.fillWidth: true
					Layout.preferredHeight: root.listHeight
					visible: Storage.tab !== "overview"
					clip: true
					model: Storage.rows
					spacing: 4
					boundsBehavior: Flickable.StopAtBounds

					Label {
						anchors.centerIn: parent
						visible: Storage.rows.length === 0
						text: Storage.scanning ? "Scanning…" : "Nothing here"
						color: Config.fgDim
					}

					delegate: MouseArea {
						id: row

						required property var modelData

						readonly property bool removable: Storage.tab !== "folders"
						readonly property bool armed: root.armedPath === modelData.path
						readonly property real share: Storage.rows.length > 0 && Storage.rows[0].bytes > 0 && Storage.sortKey === "size" && Storage.descending
							? modelData.bytes / Storage.rows[0].bytes
							: Math.min(1, modelData.bytes / Math.max(1, Storage.diskTotal) * 20)

						width: ListView.view.width - 8
						height: root.rowHeight
						hoverEnabled: true
						onContainsMouseChanged: if (!containsMouse && armed) root.armedPath = ""

						Rectangle {
							anchors.fill: parent
							radius: Config.radius - 4
							color: row.containsMouse ? Config.bgAlt : "transparent"
						}

						ColumnLayout {
							anchors.fill: parent
							anchors.leftMargin: 8
							anchors.rightMargin: 8
							spacing: 2

							RowLayout {
								Layout.fillWidth: true
								Layout.topMargin: 4
								spacing: 8

								Label {
									Layout.fillWidth: true
									Layout.minimumWidth: 0
									text: row.modelData.name
									elide: Text.ElideMiddle
									font.pixelSize: Config.fontSize - 1
								}

								Label {
									text: Storage.kindNames[row.modelData.kind] ?? row.modelData.kind
									color: Config.fgDim
									font.pixelSize: Config.fontSize - 4
								}

								Label {
									Layout.preferredWidth: 60
									horizontalAlignment: Text.AlignRight
									text: Storage.age(row.modelData.mtime)
									color: Storage.sortKey === "age" ? Config.accent : Config.fgDim
									font.pixelSize: Config.fontSize - 3
								}

								Label {
									Layout.preferredWidth: 70
									horizontalAlignment: Text.AlignRight
									text: Storage.size(row.modelData.bytes)
									color: Storage.sortKey === "size" ? Config.accent : Config.fg
									font.pixelSize: Config.fontSize - 2
								}
							}

							RowLayout {
								Layout.fillWidth: true
								spacing: 6

								Label {
									Layout.fillWidth: true
									Layout.minimumWidth: 0
									text: row.modelData.path.replace(Storage.home, "~")
									color: Config.fgDim
									font.pixelSize: Config.fontSize - 4
									elide: Text.ElideMiddle
								}

								Item {
									Layout.preferredWidth: 110
									Layout.preferredHeight: 16
									visible: row.removable

									Button2 {
										anchors.right: parent.right
										opacity: row.containsMouse && !row.armed ? 1 : 0
										enabled: opacity > 0
										text: row.modelData.kind === "trash" ? "empty" : "remove"
										tone: Config.red
										onClicked: root.armedPath = row.modelData.path
									}

									Row {
										anchors.right: parent.right
										spacing: 6
										opacity: row.armed ? 1 : 0
										enabled: row.armed

										Button2 {
											text: "cancel"
											tone: Config.fgDim
											onClicked: root.armedPath = ""
										}

										Button2 {
											text: "sure?"
											tone: Config.red
											onClicked: {
												// Disarm first: removing the row destroys this delegate.
												const item = row.modelData;
												root.armedPath = "";
												Storage.remove(item);
											}
										}
									}
								}
							}

							Rectangle {
								Layout.fillWidth: true
								Layout.preferredHeight: 3
								radius: 1.5
								color: Config.bgAlt

								Rectangle {
									width: parent.width * Math.max(0.01, row.share)
									height: parent.height
									radius: 1.5
									color: Config.accent
								}
							}
						}
					}
				}

				Label {
					Layout.fillWidth: true
					Layout.bottomMargin: 4
					text: "Esc to close · cache is rebuilt by its apps as needed"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
				}
			}
		}
	}

	component Button2: MouseArea {
		id: button

		property string text
		property color tone

		implicitWidth: label.implicitWidth + 14
		implicitHeight: 18
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor

		Rectangle {
			anchors.fill: parent
			radius: 4
			color: button.containsMouse ? Qt.rgba(button.tone.r, button.tone.g, button.tone.b, 0.25)
				: "transparent"
			border.width: 1
			border.color: button.tone
			opacity: button.enabled ? 1 : 0.4
		}

		Label {
			id: label

			anchors.centerIn: parent
			text: button.text
			color: button.tone
			font.pixelSize: Config.fontSize - 3
		}
	}

	component Tab: MouseArea {
		id: tab

		property string label
		property string key

		implicitWidth: text.implicitWidth + 16
		implicitHeight: 24
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: { Storage.tab = tab.key; root.armedPath = ""; }

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: Storage.tab === tab.key ? Config.bgAlt : "transparent"
			border.width: tab.containsMouse ? 1 : 0
			border.color: Config.border
		}

		Label {
			id: text

			anchors.centerIn: parent
			text: tab.label
			color: Storage.tab === tab.key ? Config.accent : Config.fgDim
			font.pixelSize: Config.fontSize - 2
		}
	}

	component SortTab: MouseArea {
		id: sort

		property string label
		property string key

		implicitWidth: text.implicitWidth + 14
		implicitHeight: 20
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: Storage.setSort(sort.key)

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: Storage.sortKey === sort.key ? Config.bgAlt : "transparent"
			border.width: sort.containsMouse ? 1 : 0
			border.color: Config.border
		}

		Label {
			id: text

			anchors.centerIn: parent
			text: sort.label + (Storage.sortKey === sort.key ? (Storage.descending ? " ↓" : " ↑") : "")
			color: Storage.sortKey === sort.key ? Config.accent : Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}
	}
}
