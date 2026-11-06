import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Lyrics for what is playing, bottom centre, the line being sung in the middle.
// Toggled with Mod+Alt+Y or the button on the media card.
//
// On the top layer, so it floats over windows but a fullscreen video or game
// covers it. Only the card takes input:
//   · double-click  the whole song / three lines
//   · scroll        read ahead or back; it picks the song up again shortly
//                   after, or from the "follow" button
//   · ctrl+scroll   lyrics sooner or later, for ones that are out of time
//   · right-click   hide
//   · drag          move it anywhere
//   · corner grip   resize: width, and how many lines show
//   · alt+scroll    text size (or the A−/A+ buttons on hover)
//   · middle-click  back to the default place, size and text size
//
// Timings that might not fit this recording (see Lyrics.doubt) start out as
// a page to scroll by hand; "follow" goes along with them anyway.
//
// Untimed lyrics get a "time it" button. While timing, the card takes the
// keyboard: Space (or a click) as each line starts, Backspace to take one
// back, Esc to give up.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	property bool expanded: false

	// Scrolled away by hand, or not trusted to follow: the page stays where
	// it is instead of tracking the current line.
	property bool detached: false
	readonly property bool tracking: Lyrics.following && !root.detached

	function attach() {
		root.detached = false;
		Lyrics.trust();
		view.recentre();
	}

	Connections {
		target: Lyrics

		function onLinesChanged() { root.detached = Lyrics.doubt !== "" && !Lyrics.timing; }
		function onTimingChanged() { if (Lyrics.timing) root.detached = false; }
	}

	// A scroll away from a song that is trusted is a look ahead, not a
	// decision to stop following it.
	Timer {
		id: reattach

		interval: 6000
		onTriggered: if (Lyrics.doubt === "") { root.detached = false; view.recentre(); }
	}

	// "No lyrics found" is worth saying, but not for the whole song.
	property bool quiet: false
	readonly property bool hasLines: Lyrics.lines.length > 0

	readonly property bool active: Config.lyrics && Lyrics.player !== null
		&& (Lyrics.timing || Lyrics.shown && !(root.quiet && !root.hasLines))

	// Only one screen's overlay takes the keyboard while timing.
	readonly property bool timingHere: Lyrics.timing && Lyrics.timingScreen === (root.screen?.name ?? "")
	onTimingHereChanged: if (root.timingHere) keys.forceActiveFocus()

	Connections {
		target: Lyrics

		function onKeyChanged() { root.quiet = false; }
		function onStatusChanged() {
			root.quiet = false;
			if (!root.hasLines && Lyrics.status !== "searching") hush.restart();
		}
	}

	Timer {
		id: hush

		interval: 5000
		onTriggered: root.quiet = true
	}

	// Stays mapped until the card has finished fading out.
	visible: root.active || card.opacity > 0

	// The whole screen, with a mask handing clicks outside the card back to
	// whatever is underneath, so moving, resizing and opening are all just the
	// card changing inside a surface that never does. Resizing the surface
	// itself every frame is what stutters.
	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	// ---- where it sits and how big ----
	//
	// Position is kept as a fraction of the room left around the card, so it
	// survives a resolution change and a card in the bottom corner stays in
	// the bottom corner as it grows. Saved on release, never mid-drag.
	readonly property int edge: 20
	readonly property int defaultWidth: 640
	readonly property int defaultFont: Config.fontSize + 5
	readonly property int defaultRows: 3

	property real fx: Persist.get("lyricsX", 0.5)
	property real fy: Persist.get("lyricsY", 1)
	property int cardWidth: Persist.get("lyricsWidth", root.defaultWidth)
	property int fontPx: Persist.get("lyricsFont", root.defaultFont)
	property int compactRows: Persist.get("lyricsRows", root.defaultRows)

	readonly property int maxWidth: Math.max(280, root.width - root.edge * 2)
	readonly property int shownWidth: Math.max(280, Math.min(root.cardWidth, root.maxWidth))

	function placeX(): real {
		return root.edge + root.fx * Math.max(0, root.width - root.edge * 2 - card.width);
	}
	function placeY(): real {
		return root.edge + root.fy * Math.max(0, root.height - root.edge * 2 - card.height);
	}

	function savePlace() {
		const roomX = root.width - root.edge * 2 - card.width;
		const roomY = root.height - root.edge * 2 - card.height;
		root.fx = roomX > 0 ? Math.max(0, Math.min(1, (card.x - root.edge) / roomX)) : 0.5;
		root.fy = roomY > 0 ? Math.max(0, Math.min(1, (card.y - root.edge) / roomY)) : 1;
		Persist.set("lyricsX", root.fx);
		Persist.set("lyricsY", root.fy);
		card.x = Qt.binding(root.placeX);
		card.y = Qt.binding(root.placeY);
	}

	function setFont(px: int) {
		root.fontPx = Math.max(10, Math.min(48, px));
		Persist.set("lyricsFont", root.fontPx);
	}

	function resetLayout() {
		root.fx = 0.5;
		root.fy = 1;
		root.cardWidth = root.defaultWidth;
		root.fontPx = root.defaultFont;
		root.compactRows = root.defaultRows;
		for (const [k, v] of [["lyricsX", 0.5], ["lyricsY", 1], ["lyricsWidth", root.defaultWidth],
				["lyricsFont", root.defaultFont], ["lyricsRows", root.defaultRows]])
			Persist.set(k, v);
	}

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: root.timingHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell-lyrics"

	mask: Region { item: card }

	readonly property int lineSize: root.fontPx
	readonly property real rowHeight: root.lineSize * 1.55

	// The one animated value; everything that grows is bound to it. Expanded
	// is always at least a page more than the size you dragged it to.
	property real rows: root.expanded || Lyrics.timing
		? Math.max(9, root.compactRows + 4) : root.compactRows
	Behavior on rows { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

	Item {
		id: keys

		focus: true
		Keys.onPressed: event => {
			if (!root.timingHere) return;
			switch (event.key) {
			case Qt.Key_Space:
			case Qt.Key_Return:
			case Qt.Key_Enter:
			case Qt.Key_Down:
				if (!event.isAutoRepeat) Lyrics.tap();
				break;
			case Qt.Key_Backspace:
			case Qt.Key_Up:
				Lyrics.untap();
				break;
			case Qt.Key_Escape:
				Lyrics.cancelTiming();
				break;
			default:
				return;
			}
			event.accepted = true;
		}
	}

	Rectangle {
		id: card

		x: root.placeX()
		y: root.placeY()
		width: root.shownWidth
		height: body.implicitHeight + Config.padding * 2
		radius: Config.radius + 4
		color: Qt.alpha(Config.surface, 0.9)
		border.width: 1
		border.color: Config.border
		clip: true

		opacity: root.active ? ((Lyrics.player?.isPlaying ?? false) ? 1 : 0.6) : 0
		Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

		HoverHandler { id: cardHover }

		MouseArea {
			id: grab

			anchors.fill: parent
			acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
			cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

			// A press that moves is a drag; one that does not is still a
			// click. Never while timing, where every press is a tap.
			drag.target: Lyrics.timing ? null : card
			drag.axis: Drag.XAndYAxis
			drag.minimumX: 0
			drag.maximumX: root.width - card.width
			drag.minimumY: 0
			drag.maximumY: root.height - card.height
			drag.onActiveChanged: if (!drag.active) root.savePlace()

			// While timing every press counts, so a quick pair of taps is
			// not swallowed as a double-click.
			onPressed: mouse => {
				if (!Lyrics.timing) return;
				if (mouse.button === Qt.RightButton) Lyrics.cancelTiming();
				else Lyrics.tap();
			}
			onClicked: mouse => {
				if (Lyrics.timing) return;
				if (mouse.button === Qt.RightButton) Lyrics.toggle();
				else if (mouse.button === Qt.MiddleButton) root.resetLayout();
			}
			onDoubleClicked: mouse => {
				if (!Lyrics.timing && mouse.button === Qt.LeftButton) root.expanded = !root.expanded;
			}
			onWheel: wheel => {
				if (wheel.modifiers & Qt.AltModifier) {
					// Alt turns some wheels sideways; take whichever axis moved.
					const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
					if (d !== 0) root.setFont(root.fontPx + (d > 0 ? 1 : -1));
					return;
				}
				if (Lyrics.timing || !root.hasLines) return;

				if (wheel.modifiers & Qt.ControlModifier) {
					if (!Lyrics.synced) return;
					Lyrics.nudge(wheel.angleDelta.y > 0 ? 0.25 : -0.25);
					offsetHint.restart();
					root.attach();
					return;
				}

				// Touchpads send pixels, wheels send notches.
				const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * root.rowHeight * 1.5;
				follow.stop();
				if (Lyrics.following) root.detached = true;
				view.contentY = Math.max(0, Math.min(view.contentHeight - view.height, view.contentY - delta));
				reattach.restart();
			}
		}

		ColumnLayout {
			id: body

			x: Config.padding + 4
			y: Config.padding
			width: card.width - (Config.padding + 4) * 2
			spacing: 6

			// ---- what this is ----
			RowLayout {
				id: header

				Layout.fillWidth: true
				spacing: 8

				Label {
					text: Config.icons.lyrics
					color: Config.accent
					font.pixelSize: Config.fontSize - 2
				}

				Label {
					Layout.fillWidth: true
					text: Lyrics.matched || ((Lyrics.player?.trackTitle ?? "")
						+ (Lyrics.player?.trackArtist ? " — " + Lyrics.player.trackArtist : ""))
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
					elide: Text.ElideRight
				}

				Label {
					readonly property bool nudging: offsetHint.running
					text: Lyrics.timing
						? Lyrics.tapIndex + "/" + Lyrics.lines.length + " · space as each line starts · ⌫ undo · esc cancel"
						: nudging || Lyrics.offset !== 0
						? (Lyrics.offset > 0 ? "+" : "") + Lyrics.offset.toFixed(2) + "s"
						: Lyrics.status === "plain" ? "not timed"
						: Lyrics.doubt !== "" ? "\uf071  " + Lyrics.doubt
						: Lyrics.source === "tapped" ? "timed by you" : ""
					color: nudging || Lyrics.timing ? Config.accent : Lyrics.doubt !== "" && Lyrics.synced ? Config.yellow : Config.fgDim
					font.pixelSize: Config.fontSize - 3
					visible: text !== ""
				}

				// Text size, only while the pointer is over the card so they do
				// not sit on top of the lyrics the rest of the time.
				Chip {
					visible: cardHover.hovered && !Lyrics.timing
					text: "A\u2212"
					onClicked: root.setFont(root.fontPx - 2)
				}

				Chip {
					visible: cardHover.hovered && !Lyrics.timing
					text: "A+"
					onClicked: root.setFont(root.fontPx + 2)
				}

				// Back to following the song, once scrolled away or held back.
				Chip {
					visible: Lyrics.synced && root.detached && !Lyrics.timing
					text: "\uf04b  follow"
					onClicked: root.attach()
				}

				// Untimed or doubtful lyrics can be timed by hand, from the top.
				Chip {
					visible: (Lyrics.status === "plain" || Lyrics.doubt !== "") && !Lyrics.timing
					text: "\uf017  time it"
					onClicked: Lyrics.startTiming(root.screen?.name ?? "")
				}

				Timer {
					id: offsetHint

					interval: 1500
				}
			}

			// ---- nothing to show ----
			Label {
				Layout.fillWidth: true
				Layout.preferredHeight: root.lineSize * 2
				visible: !root.hasLines
				horizontalAlignment: Text.AlignHCenter
				color: Config.fgDim
				font.pixelSize: Config.fontSize + 1
				text: ({
					searching: "Looking for lyrics…",
					instrumental: "♪  Instrumental",
					missing: "No lyrics found",
					error: "Couldn't reach lrclib.net",
					idle: ""
				})[Lyrics.status] ?? ""
			}

			// ---- the lyrics ----
			Flickable {
				id: view

				Layout.fillWidth: true
				Layout.preferredHeight: root.rows * root.rowHeight
				visible: root.hasLines
				clip: true
				// Scrolling is the card's wheel handler's job, so that a scroll
				// can also mean "stop following" and ctrl+scroll can mean
				// something else entirely.
				interactive: false
				boundsBehavior: Flickable.StopAtBounds
				contentWidth: width
				contentHeight: column.implicitHeight + (Lyrics.following ? height : 0)


				// Keeps the current line in the middle, however many lines
				// above it wrapped.
				function recentre() {
					if (!root.tracking) return;
					const line = lines.itemAt(Lyrics.index);
					if (!line) return;
					follow.to = Math.max(0, line.y + line.height / 2);
					follow.restart();
				}

				NumberAnimation {
					id: follow

					target: view
					property: "contentY"
					duration: 380
					easing.type: Easing.OutCubic
				}

				Connections {
					target: Lyrics

					function onIndexChanged() { view.recentre(); }
					function onLinesChanged() { view.contentY = 0; Qt.callLater(view.recentre); }
				}

				// No recentre on resize: the column starts half a view down,
				// so the contentY that centres a line does not depend on the
				// view's height, and the line stays put while it grows.

				Column {
					id: column

					// Half a view of space above, so the first line can sit
					// in the middle too.
					y: Lyrics.following ? view.height / 2 : 0
					width: view.width
					spacing: 4

					Repeater {
						id: lines

						model: Lyrics.lines

						Label {
							required property var modelData
							required property int index

							readonly property int distance: Math.abs(index - Lyrics.index)
							// While timing, "current" is the line waiting for a tap.
							readonly property bool current: distance === 0 && Lyrics.following

							width: column.width
							horizontalAlignment: Text.AlignHCenter
							wrapMode: Text.WordWrap
							text: modelData.text
							font.pixelSize: root.lineSize
							font.weight: current ? Font.DemiBold : Font.Normal
							color: current ? (Lyrics.timing ? Config.accent : Config.fg) : Config.fgDim
							opacity: !Lyrics.following ? 0.9 : current ? 1 : distance === 1 ? 0.65 : 0.4
							scale: current || !Lyrics.following ? 1 : 0.94

							Behavior on opacity { NumberAnimation { duration: 260 } }
							Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
						}
					}
				}
			}
		}

		// Bottom-right grip. Width is width; height is counted in lines, so the
		// card always ends on a whole one rather than half a line cut off.
		MouseArea {
			id: grip

			visible: !Lyrics.timing && (cardHover.hovered || pressed)
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			width: 18
			height: 18
			cursorShape: Qt.SizeFDiagCursor
			preventStealing: true

			property real startX
			property real startY
			property int startWidth
			property int startRows

			onPressed: mouse => {
				const p = mapToItem(null, mouse.x, mouse.y);
				startX = p.x;
				startY = p.y;
				startWidth = root.shownWidth;
				startRows = root.compactRows;
				// Pin the top-left while resizing; the fractions are worked out
				// again from wherever it ends up.
				card.x = card.x;
				card.y = card.y;
			}

			onPositionChanged: mouse => {
				if (!pressed) return;
				const p = mapToItem(null, mouse.x, mouse.y);
				root.cardWidth = Math.max(280, Math.min(root.maxWidth - 0, startWidth + (p.x - startX)));
				if (!root.expanded)
					root.compactRows = Math.max(1, Math.min(15, startRows + Math.round((p.y - startY) / root.rowHeight)));
			}

			onReleased: {
				Persist.set("lyricsWidth", root.cardWidth);
				Persist.set("lyricsRows", root.compactRows);
				root.savePlace();
			}

			Label {
				anchors.right: parent.right
				anchors.bottom: parent.bottom
				anchors.margins: 3
				text: "\u25e2"
				color: grip.containsMouse || grip.pressed ? Config.accent : Config.fgDim
				font.pixelSize: Config.fontSize - 4
			}
		}
	}

	component Chip: MouseArea {
		id: chip

		property string text

		implicitWidth: chipLabel.implicitWidth + 14
		implicitHeight: chipLabel.implicitHeight + 6
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor

		Rectangle {
			anchors.fill: parent
			radius: height / 2
			color: chip.containsMouse ? Qt.alpha(Config.accent, 0.25) : "transparent"
			border.width: 1
			border.color: Config.accent
		}

		Label {
			id: chipLabel

			anchors.centerIn: parent
			text: chip.text
			color: Config.accent
			font.pixelSize: Config.fontSize - 3
		}
	}
}
