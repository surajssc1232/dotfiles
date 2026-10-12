import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs
import qs.widgets

// What is playing, as a card on the desktop, top right under the bar.
// Click it to open up the artwork.
//
// Only mapped while some player is playing or paused on a track, so with
// nothing on there is no surface at all.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	// The player that is playing, else one that is paused on something.
	readonly property var player: {
		const all = Mpris.players.values;
		return all.find(p => p.isPlaying)
			?? all.find(p => p.playbackState === MprisPlaybackState.Paused && p.trackTitle !== "")
			?? null;
	}

	readonly property real length: root.player?.lengthSupported ? root.player.length : 0
	readonly property real position: root.player?.positionSupported ? root.player.position : 0

	function clock(seconds: real): string {
		const s = Math.max(0, Math.floor(seconds));
		return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
	}

	property bool expanded: false

	visible: root.player !== null

	// As large as the card can get, with a mask handing clicks outside it back
	// to the desktop, so growing is only an animation of the card inside.
	anchors {
		top: true
		right: true
		bottom: true
	}

	margins {
		top: Config.barMargin * 2 + Config.barHeight + Config.barMargin
		right: Config.barMargin
	}

	implicitWidth: 400
	mask: Region { item: card }

	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	WlrLayershell.layer: WlrLayer.Bottom
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	WlrLayershell.namespace: "desktop-media"

	// Position is not pushed by most players; ask for it while playing.
	Timer {
		interval: 1000
		repeat: true
		running: root.visible && (root.player?.isPlaying ?? false)
		onTriggered: root.player?.positionChanged()
	}

	Panel {
		id: card

		anchors.top: parent.top
		anchors.right: parent.right
		width: 340
		height: body.implicitHeight + Config.padding * 2
		clip: true

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: root.expanded = !root.expanded
		}

		ColumnLayout {
			id: body

			x: Config.padding
			y: Config.padding
			width: card.width - Config.padding * 2
			spacing: 12

			// ---- big artwork ----
			Rectangle {
				Layout.fillWidth: true
				Layout.preferredHeight: root.expanded ? width : 0
				Layout.bottomMargin: root.expanded ? 0 : -12
				radius: Config.radius - 4
				color: Config.bgAlt
				clip: true
				opacity: root.expanded ? 1 : 0
				visible: Layout.preferredHeight > 0

				Behavior on Layout.preferredHeight {
					NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
				}
				Behavior on opacity { NumberAnimation { duration: 200 } }

				Image {
					anchors.fill: parent
					source: root.player?.trackArtUrl ?? ""
					fillMode: Image.PreserveAspectCrop
					asynchronous: true
					visible: status === Image.Ready
				}

				Label {
					anchors.centerIn: parent
					text: Config.icons.music
					color: Config.fgDim
					font.pixelSize: 64
					visible: !(root.player?.trackArtUrl)
				}
			}

			// ---- track ----
			RowLayout {
				Layout.fillWidth: true
				spacing: 12

				Rectangle {
					Layout.preferredWidth: root.expanded ? 0 : 72
					Layout.preferredHeight: 72
					Layout.rightMargin: root.expanded ? -12 : 0
					opacity: root.expanded ? 0 : 1
					Behavior on Layout.preferredWidth {
						NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
					}
					Behavior on opacity { NumberAnimation { duration: 160 } }
					radius: Config.radius - 4
					color: Config.bgAlt
					clip: true

					Image {
						anchors.fill: parent
						source: root.player?.trackArtUrl ?? ""
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						visible: status === Image.Ready
					}

					Label {
						anchors.centerIn: parent
						text: Config.icons.music
						color: Config.fgDim
						font.pixelSize: 26
						visible: !(root.player?.trackArtUrl)
					}
				}

				ColumnLayout {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					spacing: 2

					Label {
						Layout.fillWidth: true
						text: root.player?.trackTitle || "Unknown title"
						font.pixelSize: Config.fontSize + 2
						elide: Text.ElideRight
					}

					Label {
						Layout.fillWidth: true
						text: root.player?.trackArtist || "Unknown artist"
						color: Config.fgDim
						elide: Text.ElideRight
					}

					Label {
						Layout.fillWidth: true
						text: root.player?.trackAlbum ?? ""
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 2
						elide: Text.ElideRight
						visible: root.expanded && text !== ""
					}

					Label {
						Layout.fillWidth: true
						text: root.player?.identity ?? ""
						color: Config.accent
						font.pixelSize: Config.fontSize - 3
						elide: Text.ElideRight
					}
				}
			}

			// ---- progress ----
			ColumnLayout {
				Layout.fillWidth: true
				spacing: 4
				visible: root.length > 0

				Item {
					id: track

					Layout.fillWidth: true
					Layout.preferredHeight: 10

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

			// ---- controls ----
			RowLayout {
				Layout.alignment: Qt.AlignHCenter
				spacing: 8

				Control {
					icon: Config.icons.prev
					hint: "Super+Alt+←"
					enabled: root.player?.canGoPrevious ?? false
					onTriggered: root.player.previous()
				}

				Control {
					icon: root.player?.isPlaying ? Config.icons.pause : Config.icons.play
					enabled: root.player?.canTogglePlaying ?? false
					size: 22
					hint: "Super+Alt+Space"
					accent: true
					onTriggered: root.player.togglePlaying()
				}

				Control {
					icon: Config.icons.next
					hint: "Super+Alt+→"
					enabled: root.player?.canGoNext ?? false
					onTriggered: root.player.next()
				}
			}
		}
	}

	component Control: MouseArea {
		id: control

		property string icon
		property int size: 16
		property bool accent: false
		property string hint
		signal triggered()

		implicitWidth: 64
		implicitHeight: 44

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		opacity: enabled ? 1 : 0.35
		onClicked: if (enabled) triggered()

		Label {
			anchors.horizontalCenter: parent.horizontalCenter
			y: 2
			text: control.icon
			color: control.accent || control.containsMouse ? Config.accent : Config.fg
			font.pixelSize: control.size
		}

		Label {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			text: control.hint
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 5
		}
	}
}
