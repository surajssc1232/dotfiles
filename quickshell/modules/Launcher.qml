import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

// Application launcher.
//
// Like the Alt-Tab overlay this holds the keyboard exclusively while it is up,
// so the compositor stops processing its own binds and every key — arrows,
// Escape, Enter — is handled here without a round trip. The list, the ranking
// and what Enter does all live in services/Launcher.qml; this is only the face.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property int rowHeight: 46
	readonly property int maxRows: 9
	readonly property int maxWidth: 620
	readonly property int headerHeight: 30
	readonly property int footerHeight: 18
	// Separator, with its margins above and below.
	readonly property int ruleHeight: 13

	// Never shorter than one row, so an empty result set has somewhere to say
	// so instead of collapsing the card to a bare field.
	readonly property int listHeight: Math.max(root.rowHeight,
		Math.min(Launcher.results.length, root.maxRows) * root.rowHeight)

	// Opens under wherever the pointer happens to be resting, so hover only
	// takes over the selection once the pointer has actually moved.
	property bool hoverArmed: false

	// True while Alt is held, which is what puts the row numbers on screen.
	property bool numbering: false

	// Where the pointer was when a row last claimed the selection, in screen
	// coordinates. Rebuilding the list under a stationary pointer creates new
	// rows beneath it, and each one reports a position change on the way in —
	// which silently moved the selection onto whatever landed under the mouse
	// every time the query changed. Comparing against this tells a real move
	// from a row arriving.
	property point lastMouse: Qt.point(-1, -1)

	readonly property string emptyText: {
		switch (Launcher.mode) {
		case "run": return "Type a command";
		case "calc": return "Type an expression";
		case "window": return "No open windows";
		case "clip": return Launcher.term ? "Nothing matches" : "Nothing copied yet";
		case "file": return FileSearch.searching ? "Searching…"
			: Launcher.term ? "No files found" : "Nothing used recently";
		default: return "No matches";
		}
	}

	visible: Launcher.open

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
	// Named so a compositor can single this surface out for an animation or a
	// rule, the way one would have matched fuzzel's.
	WlrLayershell.namespace: "quickshell-launcher"

	onVisibleChanged: {
		root.hoverArmed = false;
		root.lastMouse = Qt.point(-1, -1);
		if (!root.visible) return;
		field.text = Launcher.query;
		field.forceActiveFocus();
		intro.restart();
	}

	Timer {
		interval: 250
		running: root.visible
		onTriggered: root.hoverArmed = true
	}

	// Dimmed backdrop; clicking anywhere outside the card closes.
	MouseArea {
		id: backdrop

		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		onPressed: Launcher.close()

		Rectangle {
			id: dim

			anchors.fill: parent
			color: "#000000"
			opacity: 0.35
		}
	}

	Panel {
		id: card

		anchors.horizontalCenter: parent.horizontalCenter
		// Sat a little above centre: the eye starts at the field, and the list
		// grows downwards from it without the whole card shifting.
		y: Math.round(root.height * 0.2)

		implicitWidth: Math.min(root.width - Config.padding * 4, root.maxWidth)
		// Summed from the fixed parts rather than measured off the children:
		// the children are sized by a layout that fills this card, so asking
		// them how tall they are is a loop.
		implicitHeight: Config.padding * 2 + root.headerHeight + root.ruleHeight
			+ root.listHeight + 4 + root.footerHeight

		transformOrigin: Item.Center

		// The card grows and shrinks with the result count as you type, which
		// is most of what makes it feel like it is answering rather than
		// redrawing.
		Behavior on implicitHeight {
			NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
		}

		ParallelAnimation {
			id: intro

			NumberAnimation {
				target: card; property: "opacity"
				from: 0; to: 1; duration: 110
			}
			NumberAnimation {
				target: card; property: "scale"
				from: 0.97; to: 1; duration: 160; easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: dim; property: "opacity"
				from: 0; to: 0.35; duration: 140
			}
		}

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Config.padding
			spacing: 0

			// ---- search field ----
			RowLayout {
				id: header

				Layout.fillWidth: true
				Layout.preferredHeight: root.headerHeight
				spacing: 8

				Label {
					text: Launcher.modeIcon[Launcher.mode] ?? Config.icons.search
					color: Config.accent
					font.pixelSize: Config.fontSize + 2
				}

				Item {
					Layout.fillWidth: true
					Layout.fillHeight: true

					TextInput {
						id: field

						anchors.fill: parent

						color: Config.fg
						font.family: Config.font
						font.pixelSize: Config.fontSize + 2
						verticalAlignment: TextInput.AlignVCenter
						selectionColor: Config.accent
						selectedTextColor: Config.bg
						clip: true

						// One-way in both directions, guarded: the service is
						// the query's owner, but a mode row rewrites it from
						// under the field, and the field must follow.
						onTextEdited: Launcher.query = field.text

						Connections {
							target: Launcher

							function onQueryChanged() {
								if (field.text !== Launcher.query)
									field.text = Launcher.query;
							}
						}

						// Placeholder, drawn rather than set: TextInput has none.
						Label {
							anchors.verticalCenter: parent.verticalCenter
							visible: field.text.length === 0
							text: Launcher.modePlaceholder[Launcher.mode] ?? "Search"
							color: Config.fgDim
							font.pixelSize: Config.fontSize + 2
						}

						Keys.onPressed: event => {
							const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
							const alt = (event.modifiers & Qt.AltModifier) !== 0;
							root.numbering = alt;

							// Alt and a digit takes the nth row directly. The
							// rows are numbered in the list while Alt is held,
							// so the mapping is never something to remember.
							if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
								Launcher.moveTo(event.key - Qt.Key_1);
								Launcher.commit();
								event.accepted = true;
								return;
							}

							switch (event.key) {
							// Delete drops the selected row from whatever
							// history produced it, and does nothing elsewhere.
							case Qt.Key_Delete:
								if (field.text.length > 0 && !ctrl) return;
								Launcher.deleteSelected();
								break;
							case Qt.Key_Down:
							case Qt.Key_Tab:
								Launcher.step(1);
								break;
							case Qt.Key_Up:
							case Qt.Key_Backtab:
								Launcher.step(-1);
								break;
							// Readline and vi steps, for hands that never leave
							// the home row.
							case Qt.Key_N:
							case Qt.Key_J:
								if (!ctrl) return;
								Launcher.step(1);
								break;
							case Qt.Key_P:
							case Qt.Key_K:
								if (!ctrl) return;
								Launcher.step(-1);
								break;
							case Qt.Key_PageDown:
								Launcher.moveTo(Launcher.index + root.maxRows);
								break;
							case Qt.Key_PageUp:
								Launcher.moveTo(Launcher.index - root.maxRows);
								break;
							// Plain Home and End belong to the text cursor.
							case Qt.Key_Home:
								if (!ctrl) return;
								Launcher.moveTo(0);
								break;
							case Qt.Key_End:
								if (!ctrl) return;
								Launcher.moveTo(Launcher.results.length - 1);
								break;
							case Qt.Key_Escape:
								Launcher.close();
								break;
							default:
								return;
							}
							event.accepted = true;
						}

						Keys.onReleased: event => {
							if (event.key === Qt.Key_Alt) root.numbering = false;
						}

						Keys.onReturnPressed: Launcher.commit()
						Keys.onEnterPressed: Launcher.commit()
					}
				}

				// Result count, and the mode name once you have left the
				// application list, so a stray prefix is never a mystery.
				Label {
					text: Launcher.mode === "app"
						? Launcher.results.length + ""
						: Launcher.modeLabel[Launcher.mode]
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
				}
			}

			Rectangle {
				id: separator

				Layout.fillWidth: true
				Layout.preferredHeight: 1
				Layout.topMargin: 8
				Layout.bottomMargin: 4
				color: Config.border
			}

			// ---- results ----
			Item {
				id: listArea

				Layout.fillWidth: true
				Layout.preferredHeight: root.listHeight

				Label {
					anchors.centerIn: parent
					visible: Launcher.results.length === 0
					text: root.emptyText
					color: Config.fgDim
				}

				ListView {
					id: list

					anchors.fill: parent
					model: Launcher.results
					clip: true

					// Driven entirely by the selection: a view that scrolls
					// independently of the highlight means the thing Enter is
					// about to launch can be off screen.
					interactive: false
					currentIndex: Launcher.index
					highlightMoveDuration: 0
					highlightRangeMode: ListView.ApplyRange
					preferredHighlightBegin: 0
					preferredHighlightEnd: Math.max(0, height - root.rowHeight)

					WheelHandler {
						onWheel: event => Launcher.step(event.angleDelta.y > 0 ? -1 : 1)
					}

					delegate: MouseArea {
						id: entry

						required property var modelData
						required property int index
						readonly property bool current: index === Launcher.index

						// Resolved once per delegate: iconPath walks the icon
						// theme on the calling thread, and with a hundred rows
						// under a changing filter that cost is paid constantly.
						readonly property string iconPath: modelData.iconName
							? Quickshell.iconPath(modelData.iconName, true) : ""

						width: list.width
						height: root.rowHeight

						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor

						// Movement, not mere presence.
						onPositionChanged: mouse => {
							if (!root.hoverArmed) return;

							const at = entry.mapToItem(null, mouse.x, mouse.y);
							if (at.x === root.lastMouse.x && at.y === root.lastMouse.y)
								return;

							root.lastMouse = at;
							Launcher.index = entry.index;
						}

						onClicked: {
							Launcher.index = entry.index;
							Launcher.commit();
						}

						Rectangle {
							anchors.fill: parent
							anchors.rightMargin: 2
							radius: Config.radius - 4
							color: entry.current ? Config.bgAlt
								: entry.containsMouse ? Qt.alpha(Config.bgAlt, 0.5)
								: "transparent"

							Behavior on color {
								ColorAnimation { duration: 90 }
							}
						}

						// Selection marker. Cheaper to read at a glance than a
						// fill alone, and it survives every theme.
						Rectangle {
							anchors.verticalCenter: parent.verticalCenter
							width: 3
							height: entry.current ? root.rowHeight - 16 : 0
							radius: 2
							color: Config.accent

							Behavior on height {
								NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
							}
						}

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 14
							anchors.rightMargin: 12
							spacing: 12

							// A copied image shows itself; nothing else says
							// "that screenshot" as quickly.
							Rectangle {
								Layout.preferredWidth: 28
								Layout.preferredHeight: 28

								visible: (entry.modelData.thumb ?? "") !== ""
								radius: 4
								color: Config.bgAlt
								clip: true

								Image {
									anchors.fill: parent
									source: entry.modelData.thumb
										? "file://" + entry.modelData.thumb : ""
									fillMode: Image.PreserveAspectCrop
									asynchronous: true
									sourceSize.width: 56
									sourceSize.height: 56
								}
							}

							IconImage {
								Layout.preferredWidth: 28
								Layout.preferredHeight: 28
								source: entry.iconPath
								visible: entry.iconPath !== ""
									&& (entry.modelData.thumb ?? "") === ""
							}

							// Not everything has an icon — a calculator result
							// never does — so the mode's glyph stands in.
							Label {
								Layout.preferredWidth: 28
								visible: entry.iconPath === ""
									&& (entry.modelData.thumb ?? "") === ""
								text: entry.modelData.glyph ?? ""
								color: entry.current ? Config.accent : Config.fgDim
								font.pixelSize: Config.fontSize + 4
								horizontalAlignment: Text.AlignHCenter
							}

							ColumnLayout {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								spacing: 0

								Label {
									Layout.fillWidth: true
									// Marked up rather than plain: the matched
									// characters are what explains the order
									// the list came back in.
									textFormat: Text.StyledText
									text: Launcher.highlight(
										entry.modelData.name ?? "",
										Launcher.highlightTerm,
										entry.current ? Config.fg : Config.accent)
									color: entry.current ? Config.accent : Config.fg
									elide: Text.ElideRight
									// A calculator result is the answer, not a
									// label, and deserves the room.
									font.pixelSize: entry.modelData.kind === "calc"
										? Config.fontSize + 5 : Config.fontSize + 1
								}

								Label {
									// The recording row shows elapsed time, read
									// live here rather than carried in the model:
									// a clock in the model would rebuild the whole
									// list every second and reset its scroll.
									readonly property string detailText:
										(entry.modelData.act?.liveClock ?? false)
											&& Recorder.recording
											? Recorder.clock()
											: (entry.modelData.detail ?? "")

									Layout.fillWidth: true
									visible: detailText !== ""
									text: detailText
									color: Config.fgDim
									font.pixelSize: Config.fontSize - 3
									elide: Text.ElideRight
								}
							}

							// Alt-number badge, shown only while Alt is down,
							// and only for the rows that have a digit.
							Rectangle {
								Layout.preferredWidth: 18
								Layout.preferredHeight: 18
								visible: root.numbering && entry.index < 9
								radius: 4
								color: Config.bgAlt
								border.width: 1
								border.color: Config.border

								Label {
									anchors.centerIn: parent
									text: entry.index + 1
									color: Config.fgDim
									font.pixelSize: Config.fontSize - 4
								}
							}

							Label {
								visible: entry.current && !root.numbering
								text: Config.icons.enter
								color: Config.accent
								font.pixelSize: Config.fontSize
							}
						}
					}
				}
			}

			// ---- key hints ----
			RowLayout {
				id: footer

				Layout.fillWidth: true
				Layout.preferredHeight: root.footerHeight
				Layout.topMargin: 4

				Label {
					Layout.fillWidth: true
					text: Config.icons.keyUp + Config.icons.keyDown + " select   "
						+ Config.icons.dot + "   Enter open   "
						+ Config.icons.dot + "   Alt+n jump   "
						+ (Launcher.mode === "clip" || Launcher.mode === "run"
							? Config.icons.dot + "   Del forget   " : "")
						+ Config.icons.dot + "   Esc close   "
						+ Config.icons.dot + "   ? modes"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
					elide: Text.ElideRight
				}
			}
		}
	}
}
