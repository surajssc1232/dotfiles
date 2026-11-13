import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs
import qs.widgets

// What is playing, as one row: artwork, track, and the three transport keys.
//
// The sidebar has the full card with progress and artwork. This is the short
// form for the control centre, where the point is pausing something without
// going to find the window it is playing in. Hidden while nothing is loaded.
Item {
	id: root

	// Keyboard cursor, set by the panel that owns it.
	property bool focused: false

	// The player that is playing, else one that is paused on something.
	readonly property var player: {
		const all = Mpris.players.values;
		return all.find(p => p.isPlaying)
			?? all.find(p => p.playbackState === MprisPlaybackState.Paused && p.trackTitle !== "")
			?? null;
	}

	// The same handles a tile offers, so the panel's keyboard navigation can
	// drive this without knowing what it is: Enter plays or pauses, and left
	// and right skip.
	readonly property bool toggleable: false
	readonly property bool stepper: true

	signal triggered()
	signal stepped(int dir)

	onTriggered: if (root.player?.canTogglePlaying) root.player.togglePlaying()
	onStepped: dir => {
		if (dir > 0 && root.player?.canGoNext) root.player.next();
		else if (dir < 0 && root.player?.canGoPrevious) root.player.previous();
	}

	visible: root.player !== null
	implicitHeight: 46

	Rectangle {
		anchors.fill: parent
		radius: Config.radius
		color: Config.bgAlt
		border.width: root.focused ? 2 : 0
		border.color: Config.fg

		Behavior on color {
			ColorAnimation { duration: Config.themeFade }
		}
	}

	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 5
		anchors.rightMargin: 6
		spacing: 10

		Rectangle {
			Layout.preferredWidth: 36
			Layout.preferredHeight: 36
			radius: Config.radius - 4
			color: Qt.alpha(Config.accent, 0.18)
			clip: true

			Label {
				anchors.centerIn: parent
				text: Config.icons.music
				color: Config.accent
				font.pixelSize: Config.fontSize + 1
				visible: art.status !== Image.Ready
			}

			Image {
				id: art

				anchors.fill: parent
				source: root.player?.trackArtUrl ?? ""
				// Decoded at the size it is drawn, not the cover's own: these
				// arrive as large as 3000px square for a 36px thumbnail.
				sourceSize.width: 72
				sourceSize.height: 72
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				visible: status === Image.Ready
			}
		}

		ColumnLayout {
			Layout.fillWidth: true
			Layout.minimumWidth: 0
			spacing: 1

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: root.player?.trackTitle || "Unknown title"
				font.pixelSize: Config.fontSize - 1
				elide: Text.ElideRight
			}

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: {
					const artist = root.player?.trackArtist ?? "";
					const app = root.player?.identity ?? "";
					return artist && app ? artist + " · " + app : artist || app;
				}
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				elide: Text.ElideRight
				visible: text !== ""
			}
		}

		RowLayout {
			spacing: 2

			Key {
				icon: Config.icons.prev
				enabled: root.player?.canGoPrevious ?? false
				onClicked: root.stepped(-1)
			}

			Key {
				icon: root.player?.isPlaying ? Config.icons.pause : Config.icons.play
				enabled: root.player?.canTogglePlaying ?? false
				primary: true
				onClicked: root.triggered()
			}

			Key {
				icon: Config.icons.next
				enabled: root.player?.canGoNext ?? false
				onClicked: root.stepped(1)
			}
		}
	}

	component Key: MouseArea {
		id: key

		property string icon
		property bool primary: false

		implicitWidth: 34
		implicitHeight: 34

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		opacity: enabled ? 1 : 0.35

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: key.primary
				? (key.containsMouse ? Config.hover(Config.accent) : Config.accent)
				: key.containsMouse ? Qt.alpha(Config.accent, 0.18) : "transparent"
			scale: key.pressed ? 0.92 : 1

			Behavior on scale {
				NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
			}
		}

		Label {
			anchors.centerIn: parent
			text: key.icon
			color: key.primary ? Config.bg : Config.fg
			font.pixelSize: Config.fontSize - 2
		}
	}
}
