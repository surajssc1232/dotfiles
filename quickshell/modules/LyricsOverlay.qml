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
//   · scroll        lyrics sooner or later, for ones that are out of time;
//                   for untimed lyrics, which do not follow along, it scrolls them
//   · right-click   hide
//
// Untimed lyrics get a "time it" button. While timing, the card takes the
// keyboard: Space (or a click) as each line starts, Backspace to take one
// back, Esc to give up.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	property bool expanded: false

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

	anchors.bottom: true
	margins.bottom: 40

	// Sized for the card fully open, with a mask handing clicks outside it
	// back to whatever is underneath, so opening is only an animation of the
	// card inside. Resizing the surface itself every frame is what stutters.
	implicitWidth: Math.min(root.screen.width - 80, 640)
	implicitHeight: Config.padding * 2 + header.implicitHeight + body.spacing + root.rowHeight * 9 + 12

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: root.timingHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell-lyrics"

	mask: Region { item: card }

	readonly property int lineSize: Config.fontSize + 5
	readonly property real rowHeight: root.lineSize * 1.55

	// The one animated value; everything that grows is bound to it.
	property real rows: root.expanded || Lyrics.timing ? 9 : 3
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

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.bottom: parent.bottom
		width: parent.width
		height: body.implicitHeight + Config.padding * 2
		radius: Config.radius + 4
		color: Qt.alpha(Config.surface, 0.9)
		border.width: 1
		border.color: Config.border
		clip: true

		opacity: root.active ? ((Lyrics.player?.isPlaying ?? false) ? 1 : 0.6) : 0
		Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			cursorShape: Qt.PointingHandCursor
			// While timing every press counts, so a quick pair of taps is
			// not swallowed as a double-click.
			onPressed: mouse => {
				if (!Lyrics.timing) return;
				if (mouse.button === Qt.RightButton) Lyrics.cancelTiming();
				else Lyrics.tap();
			}
			onClicked: mouse => {
				if (!Lyrics.timing && mouse.button === Qt.RightButton) Lyrics.toggle();
			}
			onDoubleClicked: mouse => {
				if (!Lyrics.timing && mouse.button === Qt.LeftButton) root.expanded = !root.expanded;
			}
			onWheel: wheel => {
				if (!Lyrics.synced || Lyrics.timing) return;
				Lyrics.nudge(wheel.angleDelta.y > 0 ? 0.25 : -0.25);
				offsetHint.restart();
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
						: Lyrics.source === "tapped" ? "timed by you" : ""
					color: nudging || Lyrics.timing ? Config.accent : Config.fgDim
					font.pixelSize: Config.fontSize - 3
					visible: text !== ""
				}

				// Untimed lyrics can be timed by hand, from the top of the song.
				MouseArea {
					id: timeIt

					visible: Lyrics.status === "plain" && !Lyrics.timing
					implicitWidth: timeItLabel.implicitWidth + 14
					implicitHeight: timeItLabel.implicitHeight + 6
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: Lyrics.startTiming(root.screen?.name ?? "")

					Rectangle {
						anchors.fill: parent
						radius: height / 2
						color: timeIt.containsMouse ? Qt.alpha(Config.accent, 0.25) : "transparent"
						border.width: 1
						border.color: Config.accent
					}

					Label {
						id: timeItLabel

						anchors.centerIn: parent
						text: "\uf017  time it"
						color: Config.accent
						font.pixelSize: Config.fontSize - 3
					}
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
				// Timed lyrics follow the song; untimed ones are read by hand.
				interactive: !Lyrics.following
				boundsBehavior: Flickable.StopAtBounds
				contentWidth: width
				contentHeight: column.implicitHeight + (Lyrics.following ? height : 0)


				// Keeps the current line in the middle, however many lines
				// above it wrapped.
				function recentre() {
					if (!Lyrics.following) return;
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
	}
}
