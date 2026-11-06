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
//   · click     the whole song / three lines
//   · scroll    lyrics sooner or later, for ones that are out of time;
//               for untimed lyrics, which do not follow along, it scrolls them
//   · right     hide
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	property bool expanded: false

	// "No lyrics found" is worth saying, but not for the whole song.
	property bool quiet: false
	readonly property bool hasLines: Lyrics.lines.length > 0

	readonly property bool active: Config.lyrics && Lyrics.shown && Lyrics.player !== null
		&& !(root.quiet && !root.hasLines)

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
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	WlrLayershell.namespace: "quickshell-lyrics"

	mask: Region { item: card }

	readonly property int lineSize: Config.fontSize + 5
	readonly property real rowHeight: root.lineSize * 1.55

	// The one animated value; everything that grows is bound to it.
	property real rows: root.expanded ? 9 : 3
	Behavior on rows { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

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
			onClicked: mouse => {
				if (mouse.button === Qt.RightButton) Lyrics.toggle();
				else root.expanded = !root.expanded;
			}
			onWheel: wheel => {
				if (!Lyrics.synced) return;
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
					text: nudging || Lyrics.offset !== 0
						? (Lyrics.offset > 0 ? "+" : "") + Lyrics.offset.toFixed(2) + "s"
						: Lyrics.status === "plain" ? "not timed · scroll to read" : ""
					color: nudging ? Config.accent : Config.fgDim
					font.pixelSize: Config.fontSize - 3
					visible: text !== ""
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
				interactive: !Lyrics.synced
				boundsBehavior: Flickable.StopAtBounds
				contentWidth: width
				contentHeight: column.implicitHeight + (Lyrics.synced ? height : 0)


				// Keeps the current line in the middle, however many lines
				// above it wrapped.
				function recentre() {
					if (!Lyrics.synced) return;
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
					y: Lyrics.synced ? view.height / 2 : 0
					width: view.width
					spacing: 4

					Repeater {
						id: lines

						model: Lyrics.lines

						Label {
							required property var modelData
							required property int index

							readonly property int distance: Math.abs(index - Lyrics.index)
							readonly property bool current: distance === 0 && Lyrics.synced

							width: column.width
							horizontalAlignment: Text.AlignHCenter
							wrapMode: Text.WordWrap
							text: modelData.text
							font.pixelSize: root.lineSize
							font.weight: current ? Font.DemiBold : Font.Normal
							color: current ? Config.fg : Config.fgDim
							opacity: !Lyrics.synced ? 0.9 : current ? 1 : distance === 1 ? 0.65 : 0.4
							scale: current || !Lyrics.synced ? 1 : 0.94

							Behavior on opacity { NumberAnimation { duration: 260 } }
							Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
						}
					}
				}
			}
		}
	}
}
