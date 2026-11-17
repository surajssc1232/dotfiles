import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Storage review, opened by clicking the CPU / memory / disk pill: how full
// the disk is, what in $HOME is junk that can go, the biggest files, and where
// the space sits — folder by folder, drilling in without a rescan. Nothing is
// removed without a second click.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property int cardWidth: 680
	readonly property int rowHeight: 46
	readonly property int listHeight: 380

	// The row whose "remove" has been clicked once, and how it is to go.
	property string armedPath: ""
	property string armedHow: ""
	property bool armedAll: false

	readonly property var kindColors: ({
		trash: Config.red, cache: Config.accent, dev: Config.blue,
		junk: Config.yellow, broken: Config.fgDim, build: Config.green,
		large: Config.yellow, folder: Config.blue, dir: Config.blue, other: Config.fgDim
	})

	readonly property bool listTab: Storage.tab !== "overview"

	function cycleTab(d: int) {
		const tabs = ["overview", "junk", "large", "folders"];
		Storage.setTab(tabs[(tabs.indexOf(Storage.tab) + d + 4) % 4]);
	}

	// The filter field when there is one, so typing filters straight away.
	function takeFocus() {
		if (root.listTab) filterField.forceActiveFocus();
		else keys.forceActiveFocus();
	}

	function disarm() {
		root.armedPath = "";
		root.armedHow = "";
		root.armedAll = false;
	}

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

	onCoveredChanged: if (!covered && visible) root.takeFocus()

	onVisibleChanged: {
		root.disarm();
		if (root.visible) {
			root.takeFocus();
			intro.restart();
		}
	}

	Connections {
		target: Storage
		function onTabChanged() { root.disarm(); list.positionViewAtBeginning(); root.takeFocus(); }
		function onFolderChanged() { root.disarm(); list.positionViewAtBeginning(); }
		function onJunkFilterChanged() { root.armedAll = false; }
	}

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.AllButtons
		onPressed: Storage.hide()
	}

	Panel {
		id: card

		// Under the pill that opened it, just below the floating bar like every
		// other bar menu, and pulled back inside the screen if it would hang
		// off the edge.
		readonly property real pillCentre: Storage.pillCentres[root.modelData.name] ?? root.width / 2

		x: Math.round(Math.max(Config.barMargin,
			Math.min(pillCentre - width / 2, root.width - width - Config.barMargin)))
		y: Config.barMargin * 2 + Config.barHeight
		width: root.cardWidth
		height: col.implicitHeight + Config.inset * 2

		// Pops in on open, the same way the bar's menus do.
		transformOrigin: Item.Top

		ParallelAnimation {
			id: intro

			NumberAnimation {
				target: card; property: "opacity"
				from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: card; property: "scale"
				from: 0.88; to: 1; duration: 280
				easing.type: Easing.OutBack; easing.overshoot: 1.3
			}
		}

		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.AllButtons
		}

		// Holds the keyboard on the overview, where there is no filter field.
		FocusScope {
			id: keys

			anchors.fill: parent
			Keys.onEscapePressed: Storage.hide()
			Keys.onPressed: event => {
				if (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) return;
				root.cycleTab(event.key === Qt.Key_Tab ? 1 : -1);
				event.accepted = true;
			}

		ColumnLayout {
			id: col

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			anchors.margins: Config.inset
			spacing: 8

			// ---- title and disk meter ----
			RowLayout {
				Layout.fillWidth: true
				Layout.topMargin: 4
				spacing: 8

				Label {
					text: Config.icons.disk + "  Storage"
					color: Config.accent
				}

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: Storage.scanning
						? (Storage.progressTotal > 0
							? "scanning " + Math.round(Storage.progress * 100) + "% · " + Storage.progressName
							: "scanning…")
						: Storage.scannedAt > 0 ? "updated " + Storage.ago(Storage.scannedAt) : ""
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
					elide: Text.ElideRight
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
					text: Storage.scanning ? "scanning" : Config.icons.refresh + " rescan"
					tone: Config.fgDim
					enabled: !Storage.scanning
					onClicked: Storage.scan()
				}
			}

			// Disk use, with the scan's progress drawn as a thin line under it.
			Item {
				Layout.fillWidth: true
				Layout.preferredHeight: 9

				Rectangle {
					width: parent.width
					height: 6
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

				Rectangle {
					anchors.bottom: parent.bottom
					width: parent.width * Storage.progress
					height: 2
					radius: 1
					color: Config.accent
					opacity: Storage.scanning ? 0.8 : 0

					Behavior on width { NumberAnimation { duration: 200 } }
					Behavior on opacity { NumberAnimation { duration: 300 } }
				}
			}

			// ---- tabs, and sorting ----
			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Tab { label: "Overview"; key: "overview" }
				Tab {
					label: "Junk"; key: "junk"
					badge: Storage.junkBytes > 0 ? Storage.size(Storage.junkBytes) : ""
				}
				Tab {
					label: "Large files"; key: "large"
					badge: Storage.largeBytes > 0 ? Storage.size(Storage.largeBytes) : ""
				}
				Tab { label: "Folders"; key: "folders" }

				Item { Layout.fillWidth: true }

				Label {
					visible: root.listTab
					text: "Sort"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}

				SortTab { visible: root.listTab; label: "Size"; key: "size" }
				SortTab { visible: root.listTab; label: "Name"; key: "name" }
				SortTab { visible: root.listTab; label: "Date"; key: "age" }
			}

			// ---- filter field, on every list ----
			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: 28
				visible: root.listTab
				radius: Config.radius - 4
				color: Config.surfaceGroup
				border.width: filterField.activeFocus ? 1 : 0
				border.color: Qt.alpha(Config.accent, 0.5)

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 10
					anchors.rightMargin: 10
					spacing: 8

					Label {
						text: Config.icons.search
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 2
					}

					TextInput {
						id: filterField

						Layout.fillWidth: true
						color: Config.fg
						font.family: Config.font
						font.pixelSize: Config.fontSize - 1
						selectionColor: Config.accent
						selectedTextColor: Config.bg
						clip: true
						text: Storage.filter
						onTextEdited: Storage.filter = text

						Connections {
							target: Storage
							function onFilterChanged() {
								if (filterField.text !== Storage.filter) filterField.text = Storage.filter;
							}
						}

						Keys.onEscapePressed: {
							if (Storage.filter) Storage.filter = "";
							else Storage.hide();
						}
						Keys.onPressed: event => {
							// Backspace on an empty field climbs out of a folder.
							if (event.key === Qt.Key_Backspace && !text && Storage.tab === "folders"
									&& Storage.folder !== Storage.home) {
								Storage.folder = Storage.parentOf(Storage.folder);
								event.accepted = true;
							} else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
								root.cycleTab(event.key === Qt.Key_Tab ? 1 : -1);
								event.accepted = true;
							}
						}

						Label {
							anchors.verticalCenter: parent.verticalCenter
							visible: !filterField.text
							text: Storage.tab === "folders" ? "Filter this folder" : "Filter by name or path"
							color: Config.fgDim
							font.pixelSize: Config.fontSize - 2
						}
					}

					Label {
						visible: Storage.filter !== ""
						text: Storage.rows.length + " match" + (Storage.rows.length === 1 ? "" : "es")
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
					}
				}
			}

			// ---- junk: kinds to narrow to, and clean all ----
			Flow {
				Layout.fillWidth: true
				visible: Storage.tab === "junk"
				spacing: 6

				Chip {
					label: "All"
					lit: Storage.junkFilter === ""
					tone: Config.accent
					onClicked: Storage.junkFilter = ""
				}

				Repeater {
					model: Storage.kindTotals

					Chip {
						required property var modelData

						label: (Storage.kindNames[modelData.kind] ?? modelData.kind)
							+ "  " + Storage.size(modelData.bytes)
						lit: Storage.junkFilter === modelData.kind
						tone: root.kindColors[modelData.kind] ?? Config.fgDim
						onClicked: Storage.junkFilter = lit ? "" : modelData.kind
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true
				visible: Storage.tab === "junk"
				spacing: 8

				Label {
					Layout.fillWidth: true
					text: Storage.cleanable.length + " item" + (Storage.cleanable.length === 1 ? "" : "s")
						+ " can be removed · " + Storage.size(Storage.cleanableBytes) + " to free"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
				}

				Button2 {
					visible: !root.armedAll
					enabled: Storage.cleanable.length > 0
					text: Storage.junkFilter || Storage.filter ? "clean these" : "clean all"
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
					text: "yes, remove " + Storage.size(Storage.cleanableBytes)
					tone: Config.red
					onClicked: { Storage.cleanAll(); root.armedAll = false; }
				}
			}

			Label {
				Layout.fillWidth: true
				visible: Storage.tab === "large"
				text: "Files over 100 MB in your home folder. Trash keeps them restorable; delete frees the space now."
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 2
				elide: Text.ElideRight
			}

			// ---- folders: where we are ----
			RowLayout {
				Layout.fillWidth: true
				visible: Storage.tab === "folders"
				spacing: 2

				Button2 {
					text: Config.icons.up
					tone: Config.fgDim
					enabled: Storage.folder !== Storage.home
					onClicked: Storage.folder = Storage.parentOf(Storage.folder)
				}

				Item { Layout.preferredWidth: 6 }

				Repeater {
					model: Storage.crumbs

					Row {
						required property var modelData
						required property int index

						spacing: 2

						Label {
							visible: index > 0
							text: " / "
							color: Config.fgDim
							font.pixelSize: Config.fontSize - 2
						}

						MouseArea {
							width: crumb.implicitWidth
							height: crumb.implicitHeight
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: Storage.folder = modelData.path

							Label {
								id: crumb

								text: modelData.name
								color: modelData.path === Storage.folder ? Config.accent
									: parent.containsMouse ? Config.fg : Config.fgDim
								font.pixelSize: Config.fontSize - 2
							}
						}
					}
				}

				Item { Layout.fillWidth: true }

				Label {
					text: Storage.folderItem ? Storage.size(Storage.folderItem.bytes) : ""
					color: Config.fg
					font.pixelSize: Config.fontSize - 2
				}

				Button2 {
					text: "show"
					tone: Config.fgDim
					onClicked: { FileSearch.reveal(Storage.folder); Storage.hide(); }
				}
			}

			// ---- overview: graphs ----
			Item {
				id: overview

				Layout.fillWidth: true
				Layout.preferredHeight: root.listHeight
				visible: Storage.tab === "overview"

				readonly property real junk: Storage.junkBytes
				readonly property real used: Math.max(0, Storage.diskUsed - junk)
				readonly property real total: Math.max(1, Storage.diskTotal)

				Label {
					anchors.centerIn: parent
					visible: Storage.items.length === 0
					text: Storage.scanning ? "Measuring your home folder…" : "Nothing measured yet"
					color: Config.fgDim
				}

				RowLayout {
					anchors.fill: parent
					spacing: 20
					visible: Storage.items.length > 0

					// Disk donut: kept, reclaimable, free.
					Item {
						Layout.preferredWidth: 170
						Layout.preferredHeight: 170
						Layout.alignment: Qt.AlignTop

						Canvas {
							anchors.fill: parent
							property real used: overview.used
							property real junk: overview.junk
							property real total: overview.total
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

						// Legend for the donut; the reclaimable line opens the junk.
						Repeater {
							model: [
								{ name: "In use", bytes: overview.used, tone: Config.accent, tab: "folders" },
								{ name: "Can be removed", bytes: overview.junk, tone: Config.yellow, tab: "junk" },
								{ name: "Free", bytes: Math.max(0, Storage.diskTotal - Storage.diskUsed), tone: Config.fgDim, tab: "" }
							]

							MouseArea {
								id: legend

								required property var modelData
								readonly property bool live: modelData.tab !== ""

								Layout.fillWidth: true
								Layout.preferredHeight: 18
								hoverEnabled: live
								cursorShape: live ? Qt.PointingHandCursor : Qt.ArrowCursor
								onClicked: {
									if (!legend.live) return;
									Storage.junkFilter = "";
									if (legend.modelData.tab === "folders") Storage.folder = Storage.home;
									Storage.setTab(legend.modelData.tab);
								}

								RowLayout {
									anchors.fill: parent
									spacing: 8

									Rectangle {
										Layout.preferredWidth: 10
										Layout.preferredHeight: 10
										radius: 5
										color: legend.modelData.tone
									}

									Label {
										Layout.fillWidth: true
										text: legend.modelData.name
											+ (legend.containsMouse ? "  " + Config.icons.chevronRight : "")
										color: legend.containsMouse ? Config.accent : Config.fg
										font.pixelSize: Config.fontSize - 2
									}

									Label {
										text: Storage.size(legend.modelData.bytes)
										color: Config.fgDim
										font.pixelSize: Config.fontSize - 2
									}
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

								MouseArea {
									id: kind

									required property var modelData

									width: kindRow.implicitWidth
									height: kindRow.implicitHeight
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: {
										Storage.setTab("junk");
										Storage.junkFilter = kind.modelData.kind;
									}

									Row {
										id: kindRow

										spacing: 5

										Rectangle {
											width: 8
											height: 8
											radius: 4
											anchors.verticalCenter: parent.verticalCenter
											color: root.kindColors[kind.modelData.kind] ?? Config.fgDim
										}

										Label {
											text: (Storage.kindNames[kind.modelData.kind] ?? kind.modelData.kind)
												+ " " + Storage.size(kind.modelData.bytes)
											color: kind.containsMouse ? Config.fg : Config.fgDim
											font.pixelSize: Config.fontSize - 4
										}
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

							MouseArea {
								id: top

								required property var modelData

								Layout.fillWidth: true
								Layout.preferredHeight: 16
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: Storage.openFolder(top.modelData.path)

								RowLayout {
									anchors.fill: parent
									spacing: 8

									Label {
										Layout.preferredWidth: 110
										text: top.modelData.name
										color: top.containsMouse ? Config.accent : Config.fg
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
												? parent.width * top.modelData.bytes / Storage.topFolders[0].bytes : 0
											height: parent.height
											radius: 4
											color: Config.blue

											Behavior on width { NumberAnimation { duration: 250 } }
										}
									}

									Label {
										Layout.preferredWidth: 64
										horizontalAlignment: Text.AlignRight
										text: Storage.size(top.modelData.bytes)
										color: Config.fgDim
										font.pixelSize: Config.fontSize - 3
									}
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
				visible: root.listTab
				clip: true
				model: Storage.rows
				spacing: 4
				boundsBehavior: Flickable.StopAtBounds
				reuseItems: true

				// The biggest row's size, which every bar is drawn against.
				readonly property real biggest: Storage.rows.reduce((m, i) => Math.max(m, i.bytes), 1)

				Label {
					anchors.centerIn: parent
					visible: Storage.rows.length === 0
					text: Storage.scanning && Storage.items.length === 0 ? "Scanning…"
						: Storage.filter ? "Nothing matches “" + Storage.filter + "”"
						: Storage.tab === "junk" ? "No junk — nothing to clean"
						: "Nothing here"
					color: Config.fgDim
				}

				delegate: MouseArea {
					id: row

					required property var modelData

					readonly property string kind: modelData.kind
					readonly property bool removable: Storage.isJunk(modelData) || kind === "large"
					readonly property bool drillable: (kind === "folder" || kind === "dir")
						&& Storage.hasChildren(modelData.path)
					readonly property bool armed: root.armedPath === modelData.path
					readonly property real share: modelData.bytes / list.biggest

					width: ListView.view.width - 8
					height: root.rowHeight
					hoverEnabled: true
					cursorShape: drillable ? Qt.PointingHandCursor : Qt.ArrowCursor
					onContainsMouseChanged: if (!containsMouse && armed) root.armedPath = ""
					onClicked: if (drillable) Storage.folder = modelData.path

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

							Rectangle {
								Layout.preferredWidth: 6
								Layout.preferredHeight: 6
								radius: 3
								color: root.kindColors[row.kind] ?? Config.fgDim
							}

							Label {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								text: row.modelData.name + (row.drillable ? "  " + Config.icons.chevronRight : "")
								color: row.kind === "other" ? Config.fgDim : Config.fg
								elide: Text.ElideMiddle
								font.pixelSize: Config.fontSize - 1
							}

							Label {
								text: Storage.kindNames[row.kind] ?? row.kind
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
								text: row.kind === "other" ? "Too small to list one by one"
									: row.modelData.path.replace(Storage.home, "~")
								color: Config.fgDim
								font.pixelSize: Config.fontSize - 4
								elide: Text.ElideMiddle
							}

							// Hover actions; a destructive one asks again first.
							Row {
								spacing: 6
								visible: row.kind !== "other"
								opacity: row.containsMouse && !row.armed ? 1 : 0
								enabled: opacity > 0

								Button2 {
									text: "show"
									tone: Config.fgDim
									onClicked: { FileSearch.reveal(row.modelData.path); Storage.hide(); }
								}

								Button2 {
									visible: row.kind === "large"
									text: "trash"
									tone: Config.yellow
									onClicked: { root.armedPath = row.modelData.path; root.armedHow = "trash"; }
								}

								Button2 {
									visible: row.removable
									text: row.kind === "trash" ? "empty" : row.kind === "large" ? "delete" : "remove"
									tone: Config.red
									onClicked: { root.armedPath = row.modelData.path; root.armedHow = "delete"; }
								}
							}

							Row {
								spacing: 6
								visible: row.armed

								Button2 {
									text: "cancel"
									tone: Config.fgDim
									onClicked: root.armedPath = ""
								}

								Button2 {
									text: root.armedHow === "trash" ? "move to trash?" : "sure? frees " + Storage.size(row.modelData.bytes)
									tone: root.armedHow === "trash" ? Config.yellow : Config.red
									onClicked: {
										// Disarm first: removing the row destroys this delegate.
										const item = row.modelData;
										const how = root.armedHow;
										root.disarm();
										if (how === "trash") Storage.trash(item);
										else Storage.remove(item);
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
								width: parent.width * Math.max(0.01, Math.min(1, row.share))
								height: parent.height
								radius: 1.5
								color: root.kindColors[row.kind] ?? Config.accent
								opacity: 0.85
							}
						}
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true
				Layout.bottomMargin: 4

				Label {
					Layout.fillWidth: true
					text: "Esc close · Tab switch · " + (Storage.tab === "folders" ? "click to open · ⌫ up · " : "")
						+ "caches are rebuilt by their apps as needed"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
					elide: Text.ElideRight
				}

				Label {
					visible: Storage.freed > 0
					text: Config.icons.check + " freed " + Storage.size(Storage.freed)
					color: Config.green
					font.pixelSize: Config.fontSize - 3
				}
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
		width: implicitWidth
		height: implicitHeight
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor

		Rectangle {
			anchors.fill: parent
			radius: 4
			color: button.containsMouse && button.enabled
				? Qt.rgba(button.tone.r, button.tone.g, button.tone.b, 0.25) : "transparent"
			border.width: 1
			border.color: button.tone
			opacity: button.enabled ? 1 : 0.4
		}

		Label {
			id: label

			anchors.centerIn: parent
			text: button.text
			color: button.tone
			opacity: button.enabled ? 1 : 0.5
			font.pixelSize: Config.fontSize - 3
		}
	}

	component Tab: MouseArea {
		id: tab

		property string label
		property string key
		property string badge

		implicitWidth: tabRow.implicitWidth + 16
		implicitHeight: 24
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			if (tab.key === "folders" && Storage.tab === "folders") Storage.folder = Storage.home;
			Storage.setTab(tab.key);
		}

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: Storage.tab === tab.key ? Config.bgAlt : "transparent"
			border.width: tab.containsMouse ? 1 : 0
			border.color: Config.border
		}

		Row {
			id: tabRow

			anchors.centerIn: parent
			spacing: 6

			Label {
				text: tab.label
				color: Storage.tab === tab.key ? Config.accent : Config.fgDim
				font.pixelSize: Config.fontSize - 2
			}

			Label {
				visible: tab.badge !== ""
				anchors.verticalCenter: parent.verticalCenter
				text: tab.badge
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 4
			}
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

	component Chip: MouseArea {
		id: chip

		property string label
		property bool lit
		property color tone

		implicitWidth: chipText.implicitWidth + 18
		implicitHeight: 22
		width: implicitWidth
		height: implicitHeight
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor

		Rectangle {
			anchors.fill: parent
			radius: height / 2
			color: chip.lit ? Qt.alpha(chip.tone, 0.22)
				: chip.containsMouse ? Config.bgAlt : "transparent"
			border.width: 1
			border.color: chip.lit ? chip.tone : Config.border
		}

		Label {
			id: chipText

			anchors.centerIn: parent
			text: chip.label
			color: chip.lit ? chip.tone : Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}
	}
}
