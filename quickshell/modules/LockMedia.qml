import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs
import qs.widgets

// What is playing, for the lock screen: cover art, track, progress and the
// transport controls. A player that is playing wins, else one paused on a
// track; with neither there is nothing to show and `hasPlayer` is false.
Rectangle {
	id: root

	readonly property var player: {
		const all = Mpris.players.values;
		return all.find(p => p.isPlaying)
			?? all.find(p => p.playbackState === MprisPlaybackState.Paused && p.trackTitle !== "")
			?? null;
	}
	readonly property bool hasPlayer: root.player !== null

	readonly property real length: root.player?.lengthSupported ? root.player.length : 0
	readonly property real position: root.player?.positionSupported ? root.player.position : 0

	function clock(seconds: real): string {
		const s = Math.max(0, Math.floor(seconds));
		return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
	}

	// Same width as the weather card it sits under.
	implicitWidth: 260
	implicitHeight: body.implicitHeight + Config.padding * 2

	radius: Config.radius
	color: Config.bg
	border.width: 1
	border.color: Config.border

	// Position is not pushed by most players; ask for it while playing.
	Timer {
		interval: 1000
		repeat: true
		running: root.visible && (root.player?.isPlaying ?? false)
		onTriggered: root.player?.positionChanged()
	}

	// Swallows clicks on the card: a click anywhere else on the lock screen
	// opens the password field, which is the wrong answer to a tap on pause.
	MouseArea {
		anchors.fill: parent
	}

	ColumnLayout {
		id: body

		anchors.fill: parent
		anchors.margins: Config.padding
		spacing: 8

		RowLayout {
			Layout.fillWidth: true
			spacing: 12

			// ---- cover art ----
			Item {
				Layout.preferredWidth: 64
				Layout.preferredHeight: 64
				Layout.alignment: Qt.AlignTop

				// The rounded shape the picture is cut to. Hidden, and used
				// only as the effect's mask: Rectangle.clip cuts to a plain
				// rectangle.
				Rectangle {
					id: artMask

					anchors.fill: parent
					radius: Config.radius - 2
					layer.enabled: true
					visible: false
				}

				Rectangle {
					anchors.fill: parent
					radius: artMask.radius
					color: Config.bgAlt
					visible: art.status !== Image.Ready

					Label {
						anchors.centerIn: parent
						text: Config.icons.music
						color: Config.fgDim
						font.pixelSize: 24
					}
				}

				Image {
					id: art

					anchors.fill: parent
					visible: false

					source: root.player?.trackArtUrl ?? ""
					fillMode: Image.PreserveAspectCrop
					asynchronous: true
					// Decoded at twice the size it is drawn, which stays sharp
					// on a scaled output without holding a full-size album.
					sourceSize: Qt.size(128, 128)
				}

				MultiEffect {
					anchors.fill: parent
					source: art
					visible: art.status === Image.Ready
					maskEnabled: true
					maskSource: artMask
				}
			}

			// ---- track and controls ----
			ColumnLayout {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				Layout.alignment: Qt.AlignVCenter
				spacing: 0

				Label {
					Layout.fillWidth: true
					text: root.player?.trackTitle || "Unknown title"
					font.pixelSize: Config.fontSize
					font.weight: Font.DemiBold
					elide: Text.ElideRight
				}

				Label {
					Layout.fillWidth: true
					text: root.player?.trackArtist || "Unknown artist"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
					elide: Text.ElideRight
				}

				RowLayout {
					Layout.topMargin: 2
					// The buttons are padded wider than their glyphs; pull the
					// first one back so its icon lines up with the title.
					Layout.leftMargin: -12
					spacing: 0

					Control {
						icon: Config.icons.prev
						enabled: root.player?.canGoPrevious ?? false
						onTriggered: root.player.previous()
					}

					Control {
						icon: root.player?.isPlaying ? Config.icons.pause : Config.icons.play
						enabled: root.player?.canTogglePlaying ?? false
						size: 18
						accent: true
						onTriggered: root.player.togglePlaying()
					}

					Control {
						icon: Config.icons.next
						enabled: root.player?.canGoNext ?? false
						onTriggered: root.player.next()
					}
				}
			}
		}

		// ---- progress ----
		ColumnLayout {
			Layout.fillWidth: true
			spacing: 0
			visible: root.length > 0

			Item {
				id: track

				Layout.fillWidth: true
				Layout.preferredHeight: 12

				Rectangle {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width
					height: 4
					radius: 2
					color: Config.bgAlt

					Rectangle {
						width: parent.width * Math.min(1, root.position / Math.max(1, root.length))
						height: parent.height
						radius: 2
						color: Config.accent
					}
				}

				MouseArea {
					anchors.fill: parent
					enabled: root.player?.canSeek ?? false
					cursorShape: Qt.PointingHandCursor
					onClicked: mouse => {
						root.player.position = root.length * mouse.x / track.width;
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true

				Label {
					text: root.clock(root.position)
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}

				Item { Layout.fillWidth: true }

				Label {
					text: root.clock(root.length)
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}
			}
		}
	}

	component Control: MouseArea {
		id: control

		property string icon
		property int size: 16
		property bool accent: false
		signal triggered()

		implicitWidth: 40
		implicitHeight: 28

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		opacity: enabled ? 1 : 0.35
		onClicked: if (enabled) triggered()

		Label {
			anchors.centerIn: parent
			text: control.icon
			color: control.accent || control.containsMouse ? Config.accent : Config.fg
			font.pixelSize: control.size
		}
	}
}
