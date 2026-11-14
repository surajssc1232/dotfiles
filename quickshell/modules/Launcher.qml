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
	// A fitted card (Claude's answer) measures its content, capped so a long
	// answer scrolls instead of growing past the screen.
	readonly property int infoMax: 440
	readonly property int infoHeight: !Launcher.webInfo ? 0
		: Launcher.webInfo.fit ? Math.min(Math.ceil(infoBody.implicitHeight) + 6, root.infoMax)
		: Launcher.webInfo.height
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

	// ---- right-click menu ----
	// ctxRow is the file row the menu is for; ctxMode is "menu", or the name of
	// the text prompt replacing it ("copy", "move", "rename"), or "delete"
	// while permanent deletion waits for a second click.
	property var ctxRow: null
	property string ctxMode: "menu"
	property point ctxAt: Qt.point(0, 0)

	function openMenu(row, at) {
		if (!row || row.kind !== "file" || !row.path) return;
		root.ctxRow = row;
		root.ctxMode = "menu";
		root.ctxAt = at;
	}

	function closeMenu() {
		root.ctxRow = null;
		field.forceActiveFocus();
	}

	// Menu entries. `prompt` ones swap the card for a text field.
	function ctxItems(): var {
		const path = root.ctxRow?.path ?? "";
		const folder = FileSearch.folder(path);
		return [
			{ label: "Open", glyph: Config.icons.arrowRight, run: () => FileSearch.open(path) },
			{ label: "Show in folder", glyph: Config.icons.inbox, run: () => FileSearch.reveal(path) },
			{ label: "Terminal here", glyph: Config.icons.terminal ?? Config.icons.arrowRight,
				run: () => Launcher.detach(Config.terminal.slice(), folder) },
			{ label: "Copy path", glyph: Config.icons.clipboard, run: () => Clipboard.copy(path) },
			{ label: "Copy to\u2026", glyph: Config.icons.clipboard, prompt: "copy", seed: FileSearch.shorten(folder) + "/" },
			{ label: "Move to\u2026", glyph: Config.icons.arrowRight, prompt: "move", seed: FileSearch.shorten(folder) + "/" },
			{ label: "Rename\u2026", glyph: Config.icons.swatch, prompt: "rename", seed: FileSearch.name(path) },
			{ label: "Move to trash", glyph: Config.icons.trash, run: () => FileSearch.trash(path), keep: true },
			{ label: "Delete permanently", glyph: Config.icons.trash, prompt: "delete", danger: true }
		];
	}

	// Enter opens; with Ctrl it shows a file in its folder, with Shift it
	// copies the path. Both fall back to a plain open on non-file rows.
	function enter(event) {
		const isFile = Launcher.selected?.kind === "file";
		if (isFile && (event.modifiers & Qt.ControlModifier)) Launcher.fileAction("reveal");
		else if (isFile && (event.modifiers & Qt.ShiftModifier)) Launcher.fileAction("copy");
		else Launcher.commit();
		event.accepted = true;
	}

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
			+ root.listHeight + 4 + root.infoHeight + root.footerHeight

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

							if (root.ctxRow) {
								if (event.key === Qt.Key_Escape) root.closeMenu();
								event.accepted = true;
								return;
							}

							if (event.key === Qt.Key_Menu
								|| (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
								const r = list.currentItem;
								root.openMenu(Launcher.selected, r
									? r.mapToItem(null, 120, r.height) : Qt.point(card.x + 80, card.y + 120));
								event.accepted = true;
								return;
							}

							// Alt and a digit takes the nth row directly. The
							// rows are numbered in the list while Alt is held,
							// so the mapping is never something to remember.
							if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
								Launcher.moveTo(event.key - Qt.Key_1);
								Launcher.commit();
								event.accepted = true;
								return;
							}

							// A slider row takes Left and Right for itself; the
							// text cursor gets them back as soon as the
							// selection moves off it.
							const slider = Launcher.selected?.kind === "slider"
								? Launcher.selected.control : "";

							switch (event.key) {
							case Qt.Key_T:
								if (!ctrl || Launcher.selected?.kind !== "file") return;
								Launcher.fileAction("terminal");
								break;
							case Qt.Key_Left:
							case Qt.Key_Right:
								if (!slider) return;
								Launcher.nudge(slider, event.key === Qt.Key_Right ? 1 : -1);
								break;
							// Delete drops the selected row from whatever
							// history produced it, and does nothing elsewhere.
							// Text to the right of the cursor still gets the
							// ordinary forward delete; at the end there is
							// none, so the key is free for the row — which is
							// what makes it reachable behind a mode prefix.
							case Qt.Key_Delete:
								if (field.cursorPosition < field.text.length && !ctrl) return;
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

						Keys.onReturnPressed: event => root.enter(event)
						Keys.onEnterPressed: event => root.enter(event)
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

					// Rows are recycled rather than destroyed and rebuilt as
					// they scroll, and a few are kept alive just outside the
					// viewport so a notch of the wheel does not have to build
					// one from scratch.
					reuseItems: true
					cacheBuffer: root.rowHeight * 6
					highlightRangeMode: ListView.ApplyRange
					preferredHighlightBegin: 0
					preferredHighlightEnd: Math.max(0, height - root.rowHeight)

					// A transparent capture layer rather than a WheelHandler:
					// the row delegates are hover-enabled MouseAreas sitting
					// above it, and the wheel never reached the handler
					// underneath them. NoButton lets clicks fall straight
					// through to the rows as before.
					MouseArea {
						anchors.fill: parent
						z: 10

						acceptedButtons: Qt.NoButton
						propagateComposedEvents: true

						// A notch is 120; a touchpad sends much smaller
						// deltas, so they accumulate into whole rows instead
						// of either doing nothing or flying down the list.
						property int wheelAccumulator: 0

						onWheel: wheel => {
							// Over a slider row the wheel moves the slider
							// instead of the selection, as it does on the tile
							// in the control centre.
							const under = list.itemAt(wheel.x + list.contentX,
								wheel.y + list.contentY);
							if (under?.isSlider) {
								wheelAccumulator = 0;
								const dir = wheel.angleDelta.y > 0 ? 1
									: wheel.angleDelta.y < 0 ? -1 : 0;
								if (dir !== 0) Launcher.nudge(under.modelData.control, dir);
								return;
							}

							wheelAccumulator += wheel.angleDelta.y;

							while (wheelAccumulator >= 120) {
								Launcher.step(-1);
								wheelAccumulator -= 120;
							}

							while (wheelAccumulator <= -120) {
								Launcher.step(1);
								wheelAccumulator += 120;
							}
						}
					}

					// Where you are in a long result list. Only present when
					// there is more than one screenful.
					Rectangle {
						anchors.right: parent.right
						anchors.rightMargin: 3
						width: 3
						radius: 2

						visible: Launcher.results.length > root.maxRows
						color: Config.fgDim
						opacity: 0.4

						height: Math.max(24, parent.height
							* (root.maxRows / Math.max(1, Launcher.results.length)))

						y: Launcher.results.length > root.maxRows
							? (parent.height - height)
								* (Launcher.index / Math.max(1, Launcher.results.length - 1))
							: 0

						Behavior on y {
							NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
						}
					}

					delegate: MouseArea {
						id: entry

						required property var modelData
						required property int index
						readonly property bool current: index === Launcher.index

						// Read live, never carried in the model: see the
						// slider section of services/Launcher.qml.
						readonly property bool isSlider: modelData.kind === "slider"
						readonly property string control: isSlider ? modelData.control : ""
						readonly property real level: isSlider
							? Launcher.sliderValue(control) : 0
						readonly property bool muted: isSlider
							&& Launcher.sliderMuted(control)

						// Memoised in the service: iconPath walks the icon
						// theme on the calling thread, and a recycled row
						// re-evaluates this every time it is reused.
						readonly property string iconPath: Launcher.icon(modelData.iconName)

						width: list.width
						height: root.rowHeight

						hoverEnabled: true
						acceptedButtons: Qt.LeftButton | Qt.RightButton
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

						onClicked: mouse => {
							Launcher.index = entry.index;
							if (mouse.button === Qt.RightButton) {
								root.openMenu(entry.modelData, entry.mapToItem(null, mouse.x, mouse.y));
								return;
							}
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
								// Decoded off the render thread, so a row
								// scrolling into view cannot stall a frame.
								asynchronous: true
								visible: entry.iconPath !== ""
									&& (entry.modelData.thumb ?? "") === ""
							}

							// Not everything has an icon — a calculator result
							// never does — so the mode's glyph stands in.
							Label {
								Layout.preferredWidth: 28
								visible: entry.iconPath === ""
									&& (entry.modelData.thumb ?? "") === ""
								text: entry.isSlider
									? Launcher.sliderGlyph(entry.control)
									: (entry.modelData.glyph ?? "")
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

							// A theme previews itself as a strip: background,
							// accent, foreground.
							Rectangle {
								visible: (entry.modelData.act?.swatches ?? []).length > 0
								implicitWidth: strip.width + 2
								implicitHeight: strip.height + 2
								color: Config.border
								Row {
									id: strip
									anchors.centerIn: parent
									Repeater {
										model: entry.modelData.act?.swatches ?? []
										Rectangle {
											required property string modelData
											width: 16
											height: 16
											color: modelData
										}
									}
								}
							}

							// ---- inline slider ----
							Item {
								id: track

								Layout.preferredWidth: Math.round(list.width * 0.32)
								Layout.preferredHeight: 18
								visible: entry.isSlider

								function commit(x) {
									Launcher.index = entry.index;
									Launcher.setSlider(entry.control,
										Math.max(0, Math.min(1, x / track.width)));
								}

								Rectangle {
									anchors.verticalCenter: parent.verticalCenter
									width: parent.width
									height: 6
									radius: 3
									color: Config.bg
									border.width: 1
									border.color: Config.border

									Rectangle {
										width: Math.round(parent.width
											* Math.max(0, Math.min(1, entry.level)))
										height: parent.height
										radius: parent.radius
										color: entry.muted ? Config.fgDim : Config.accent
									}
								}

								// Above the row's own MouseArea, so pressing the
								// bar sets the level rather than committing
								// (which would mute).
								MouseArea {
									anchors.fill: parent
									anchors.leftMargin: -4
									anchors.rightMargin: -4
									preventStealing: true
									cursorShape: Qt.PointingHandCursor

									onPressed: event => track.commit(event.x)
									onPositionChanged: event => {
										if (pressed) track.commit(event.x);
									}
								}
							}

							Label {
								Layout.preferredWidth: 44
								visible: entry.isSlider
								text: entry.isSlider ? Launcher.sliderReadout(entry.control) : ""
								color: entry.current ? Config.accent : Config.fgDim
								font.pixelSize: Config.fontSize - 2
								horizontalAlignment: Text.AlignRight
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
								visible: entry.current && !root.numbering && !entry.isSlider
								text: Config.icons.enter
								color: Config.accent
								font.pixelSize: Config.fontSize
							}
						}
					}
				}
			}

			// ---- web preview ----
			RowLayout {
				Layout.fillWidth: true
				Layout.preferredHeight: root.infoHeight
				Layout.topMargin: 8
				visible: Launcher.webInfo !== null
				spacing: 12
				clip: true

				Image {
					Layout.preferredWidth: 100
					Layout.preferredHeight: 100
					Layout.alignment: Qt.AlignTop
					Layout.leftMargin: 8
					visible: status === Image.Ready
					source: Launcher.webInfo?.image ?? ""
					fillMode: Image.PreserveAspectFit
					asynchronous: true
				}

				Flickable {
					id: infoFlick
					Layout.fillWidth: true
					Layout.fillHeight: true
					Layout.leftMargin: 8
					contentWidth: width
					contentHeight: infoBody.implicitHeight
					clip: true
					boundsBehavior: Flickable.StopAtBounds
					interactive: contentHeight > height

					// Follow a streaming answer down, unless the user scrolled up.
					property bool pinned: true
					onMovementEnded: pinned = contentY >= contentHeight - height - 4
					onContentHeightChanged: if (pinned && Launcher.webInfo?.fit)
						contentY = Math.max(0, contentHeight - height)
					Connections {
						target: Launcher
						function onTermChanged() { infoFlick.pinned = true; infoFlick.contentY = 0; }
					}

				ColumnLayout {
					id: infoBody
					width: infoFlick.width - 8
					spacing: 6

					Label {
						Layout.fillWidth: true
						visible: (Launcher.webInfo?.heading ?? "") !== ""
						text: Launcher.webInfo?.heading ?? ""
						color: Config.fg
						font.pixelSize: Config.fontSize + 8
						elide: Text.ElideRight
					}

					Repeater {
						model: Launcher.webInfo?.rows ?? []

						Loader {
							required property var modelData
							Layout.fillWidth: true
							sourceComponent: modelData.kind === "code" ? codeBox : textRow
							property var row: modelData
						}
					}
				}
				}
			}

			Component {
				id: textRow

				Label {
					readonly property var modelData: parent.row
					width: parent.width
					leftPadding: modelData.kind === "def" || modelData.kind === "ex" ? 10 : 0
					topPadding: modelData.kind === "sep" ? 4 : 0
					textFormat: modelData.kind === "rich" ? Text.StyledText : Text.PlainText
					text: modelData.kind === "sep" ? ""
						: modelData.kind === "loading"
							? modelData.text + "\u2009" + "\u2022".repeat(dots) + "\u2009".repeat(3 - dots)
							: modelData.text

					// "thinking" with dots that fill in, and a gentle pulse.
					property int dots: 0
					Timer {
						running: parent.modelData.kind === "loading" && parent.visible
						interval: 350
						repeat: true
						onTriggered: parent.dots = (parent.dots + 1) % 4
					}
					SequentialAnimation on opacity {
						running: modelData.kind === "loading"
						loops: Animation.Infinite
						NumberAnimation { from: 1; to: 0.45; duration: 700; easing.type: Easing.InOutSine }
						NumberAnimation { from: 0.45; to: 1; duration: 700; easing.type: Easing.InOutSine }
					}

					color: modelData.kind === "def" || modelData.kind === "body" || modelData.kind === "rich"
						? Config.fg : Config.fgDim
					font.italic: modelData.kind === "pos"
					font.pixelSize: modelData.kind === "ex" || modelData.kind === "source" || modelData.kind === "loading"
						? Config.fontSize - 3 : Config.fontSize - 1
					wrapMode: Text.WordWrap
					maximumLineCount: modelData.lines ?? 2
					elide: Text.ElideRight
				}
			}

			// A fenced block: language and copy button on top, then the code on
			// a darker panel, unwrapped and scrollable sideways.
			Component {
				id: codeBox

				Rectangle {
					readonly property var modelData: parent.row
					width: parent.width
					implicitHeight: codeCol.implicitHeight
					radius: 10
					color: Config.surfaceGroup
					border.color: Config.border
					border.width: 1
					clip: true

					ColumnLayout {
						id: codeCol
						anchors.left: parent.left
						anchors.right: parent.right
						spacing: 0

						RowLayout {
							Layout.fillWidth: true
							Layout.leftMargin: 12
							Layout.rightMargin: 6
							Layout.topMargin: 4
							Layout.bottomMargin: 2

							Label {
								Layout.fillWidth: true
								text: modelData.lang
								color: Config.fgDim
								font.pixelSize: Config.fontSize - 3
							}

							Label {
								id: copyLabel
								property bool done: false
								text: done ? "copied" : Config.icons.clipboard + " copy"
								color: copyArea.containsMouse ? Config.fg : Config.fgDim
								font.pixelSize: Config.fontSize - 3
								padding: 4

								Timer { id: copyReset; interval: 1500; onTriggered: copyLabel.done = false }
								MouseArea {
									id: copyArea
									anchors.fill: parent
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: {
										Quickshell.execDetached({ command: ["wl-copy", "--", modelData.code] });
										copyLabel.done = true;
										copyReset.restart();
									}
								}
							}
						}

						Rectangle {
							Layout.fillWidth: true
							Layout.preferredHeight: 1
							color: Config.border
						}

						Flickable {
							Layout.fillWidth: true
							Layout.preferredHeight: codeText.implicitHeight + 16
							contentWidth: codeText.implicitWidth + 24
							contentHeight: height
							flickableDirection: Flickable.HorizontalFlick
							boundsBehavior: Flickable.StopAtBounds
							interactive: contentWidth > width
							clip: true

							Text {
								id: codeText
								x: 12
								y: 8
								text: modelData.html
								textFormat: Text.StyledText
								color: Config.fg
								font.family: Config.font
								font.pixelSize: Config.fontSize - 2
								lineHeight: 1.15
								wrapMode: Text.NoWrap
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
						+ (Launcher.selected?.kind === "slider"
							? Config.icons.dot + "   \u2190\u2192 adjust   "
								+ (Launcher.selected.control !== "brightness"
									? Config.icons.dot + "   Enter mute   " : "")
							: Config.icons.dot + "   Enter open   ")
						+ (Launcher.selected?.kind === "file"
							? Config.icons.dot + "   ^Enter show in folder   \u21e7Enter copy path   ^T terminal   " : "")
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

	// ---- right-click card ----
	// Sits where the click landed, nudged back inside the screen. The backdrop
	// swallows the click that dismisses it so it never reaches the list below.
	MouseArea {
		anchors.fill: parent
		visible: root.ctxRow !== null
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		onPressed: root.closeMenu()

		Panel {
			id: ctxCard

			readonly property bool prompting: root.ctxMode !== "menu"
			readonly property var items: root.ctxRow ? root.ctxItems() : []

			implicitWidth: prompting ? 360 : 220
			implicitHeight: prompting ? 92 : items.length * 30 + Config.padding * 2

			x: Math.max(8, Math.min(root.width - implicitWidth - 8, root.ctxAt.x))
			y: Math.max(8, Math.min(root.height - implicitHeight - 8, root.ctxAt.y))

			// Stops a press inside the card reaching the dismissing backdrop.
			MouseArea { anchors.fill: parent }

			Column {
				anchors.fill: parent
				anchors.margins: Config.padding
				visible: !ctxCard.prompting

				Repeater {
					model: ctxCard.items

					delegate: MouseArea {
						id: item

						required property var modelData

						width: parent.width
						height: 30
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor

						onClicked: {
							const m = item.modelData;
							if (m.prompt) {
								root.ctxMode = m.prompt;
								prompt.text = m.seed ?? "";
								if (m.prompt === "delete") confirmKeys.forceActiveFocus();
								else {
									prompt.forceActiveFocus();
									prompt.selectAll();
								}
								return;
							}
							const run = m.run;
							root.closeMenu();
							if (!m.keep) Launcher.close();
							run();
						}

						Rectangle {
							anchors.fill: parent
							radius: Config.radius - 4
							color: item.containsMouse ? Config.bgAlt : "transparent"
						}

						Row {
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 8
							spacing: 10

							Label {
								text: item.modelData.glyph ?? ""
								color: item.modelData.danger ? "#e5484d" : Config.fgDim
								font.pixelSize: Config.fontSize
							}
							Label {
								text: item.modelData.label
								color: item.modelData.danger ? "#e5484d" : Config.fg
								font.pixelSize: Config.fontSize - 1
							}
						}
					}
				}
			}

			// Prompt: destination, new name, or the delete confirmation.
			Column {
				anchors.fill: parent
				anchors.margins: Config.padding
				spacing: 8
				visible: ctxCard.prompting

				Label {
					width: parent.width
					text: root.ctxMode === "copy" ? "Copy to (folder or new path)"
						: root.ctxMode === "move" ? "Move to (folder or new path)"
						: root.ctxMode === "rename" ? "New name"
						: "Delete " + (root.ctxRow ? FileSearch.name(root.ctxRow.path) : "") + " forever?"
					color: root.ctxMode === "delete" ? "#e5484d" : Config.fgDim
					font.pixelSize: Config.fontSize - 2
					elide: Text.ElideMiddle
				}

				TextInput {
					id: prompt

					width: parent.width
					visible: root.ctxMode !== "delete"
					color: Config.fg
					font.family: Config.font
					font.pixelSize: Config.fontSize
					selectionColor: Config.accent
					selectedTextColor: Config.bg
					clip: true

					Keys.onEscapePressed: root.closeMenu()
					Keys.onReturnPressed: ctxCard.confirm()
					Keys.onEnterPressed: ctxCard.confirm()
				}

				Item {
					id: confirmKeys

					width: parent.width
					height: 24
					visible: root.ctxMode === "delete"

					Keys.onEscapePressed: root.closeMenu()
					Keys.onReturnPressed: ctxCard.confirm()

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: "Enter to confirm  \u00b7  Esc to cancel"
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 2
					}
				}
			}

			function confirm() {
				const path = root.ctxRow?.path ?? "";
				const text = prompt.text.trim();
				const mode = root.ctxMode;
				if (!path || (mode !== "delete" && !text)) return;

				root.closeMenu();
				if (mode === "copy") FileSearch.copyTo(path, text);
				else if (mode === "move") FileSearch.moveTo(path, text);
				else if (mode === "rename") FileSearch.rename(path, text);
				else if (mode === "delete") FileSearch.remove(path);
			}
		}
	}
}
