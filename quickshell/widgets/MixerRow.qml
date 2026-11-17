import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs
import qs.services

// One line of the mixer: an application stream or a device, with its volume,
// mute and a live level meter.
//
// An application also says which device it is playing to (or recording from)
// and can be sent to another. A device can be made the default, has its
// ports (speakers or headphones), and a left/right balance for stereo.
Item {
	id: root

	required property var node
	property real max: 1
	// Meters only run while the mixer is on screen.
	property bool live: false
	// The default device's row at the top of the mixer: bigger, no "set default".
	property bool featured: false

	readonly property bool isStream: node?.isStream ?? false
	readonly property bool isDefault: !isStream
		&& (node === Audio.sink || node === Audio.source)
	readonly property var audio: node?.audio ?? null
	readonly property real volume: audio?.volume ?? 0
	readonly property bool muted: audio?.muted ?? false
	readonly property var device: isStream ? Audio.deviceOf(node) : null
	readonly property var portInfo: !isStream ? (Audio.ports[node?.name ?? ""] ?? null) : null
	readonly property bool stereo: (audio?.volumes ?? []).length === 2

	// The highest this row's volume has been, so its slider never loses
	// range. Without it, an app sitting above 100% with boost off (Helium
	// at 130%) got a track that ended at its volume; dragging it down shrank
	// the track to 100%, and there was no way back up to where it had been.
	property real reach: 1
	onVolumeChanged: if (volume > reach) reach = Math.min(Config.volumeMax, volume)
	Component.onCompleted: reach = Math.min(Config.volumeMax, Math.max(1, volume))

	// Device picker (streams) or the balance and ports drawer (devices).
	property bool open: false

	readonly property string iconPath: isStream ? Audio.streamIcon(node) : ""

	implicitHeight: col.implicitHeight + 16

	// An app's own stream: Quickshell reads its level directly, after the
	// app's volume.
	PwNodePeakMonitor {
		id: meter
		node: root.isStream ? root.node : null
		enabled: root.live && root.isStream && root.node !== null
	}

	// A microphone or other input, read by a small recorder that works with
	// any profile (see scripts/level-meter.py).
	property real inputPeak: 0

	Process {
		running: root.live && !root.isStream && root.node !== null && !root.node.isSink
		command: ["python3", Quickshell.shellPath("scripts/level-meter.py"), root.node?.name ?? ""]
		stdout: SplitParser {
			onRead: line => root.inputPeak = Number(line) || 0
		}
		onRunningChanged: if (!running) root.inputPeak = 0
	}

	// What the meter under the slider shows, on the slider's own scale.
	readonly property real level: !root.live ? -1
		: root.isStream ? (root.muted ? 0 : Audio.shown(meter.peak))
		: root.node?.isSink ? Audio.outputLevel(root.node)
		: (root.muted ? 0 : Audio.shown(root.inputPeak))

	Rectangle {
		anchors.fill: parent
		radius: Config.radius - 2
		color: root.featured ? "transparent"
			: hover.hovered || root.open ? Qt.alpha(Config.fg, 0.04) : "transparent"
		border.width: root.isDefault && !root.featured ? 1 : 0
		border.color: Qt.alpha(Config.accent, 0.45)

		HoverHandler { id: hover }
	}

	ColumnLayout {
		id: col

		anchors.left: parent.left
		anchors.right: parent.right
		anchors.top: parent.top
		anchors.margins: 8
		spacing: 6

		// ---- name, readout, mute ----
		RowLayout {
			Layout.fillWidth: true
			spacing: 10

			Item {
				Layout.preferredWidth: root.featured ? 30 : 24
				Layout.preferredHeight: root.featured ? 30 : 24

				IconImage {
					anchors.fill: parent
					visible: root.iconPath !== ""
					source: root.iconPath
					asynchronous: true
				}

				Rectangle {
					anchors.fill: parent
					visible: root.iconPath === ""
					radius: width / 2
					color: Qt.alpha(root.isDefault ? Config.accent : Config.fg, 0.12)

					Label {
						anchors.centerIn: parent
						text: root.isStream ? Config.icons.music
							: root.node?.isSink ? (Audio.isHeadset(root.node) ? Config.icons.device["audio-headset"] : Config.icons.volHigh)
							: Config.icons.mic
						color: root.isDefault ? Config.accent : Config.fgDim
						font.pixelSize: root.featured ? Config.fontSize + 1 : Config.fontSize - 1
					}
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				spacing: 0

				Label {
					Layout.fillWidth: true
					text: root.isStream
						? ((root.node?.properties ?? ({}))["application.name"] || Audio.label(root.node))
						: Audio.label(root.node)
					color: Config.fg
					font.pixelSize: root.featured ? Config.fontSize : Config.fontSize - 1
					font.weight: root.featured ? Font.DemiBold : Font.Normal
					elide: Text.ElideRight
				}

				Label {
					Layout.fillWidth: true
					visible: text !== ""
					text: {
						if (root.isStream) {
							const media = (root.node?.properties ?? ({}))["media.name"] ?? "";
							return /^(playback|audio stream|audio-src|output|audio|record|capture)$/i.test(media) ? "" : media;
						}
						const port = root.portInfo?.ports.find(p => p.name === root.portInfo.active);
						return (root.isDefault ? "Default" : "") + (port ? (root.isDefault ? " · " : "") + port.description : "");
					}
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
					elide: Text.ElideRight
				}
			}

			Label {
				text: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
				color: root.muted ? Config.red : root.volume > 1.001 ? Config.yellow : Config.fg
				font.pixelSize: root.featured ? Config.fontSize + 2 : Config.fontSize - 2
				font.weight: root.featured ? Font.DemiBold : Font.Normal
			}

			// Mute.
			MouseArea {
				id: muteBtn

				Layout.preferredWidth: 26
				Layout.preferredHeight: 26
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: if (root.audio) root.audio.muted = !root.audio.muted

				Rectangle {
					anchors.fill: parent
					radius: 13
					color: root.muted ? Qt.alpha(Config.red, 0.22)
						: muteBtn.containsMouse ? Config.bgAlt : "transparent"
				}

				Label {
					anchors.centerIn: parent
					text: root.node?.isSink
						? (root.muted ? Config.icons.volMute : Config.icons.volHigh)
						: (root.muted ? Config.icons.micOff : Config.icons.mic)
					color: root.muted ? Config.red : Config.fgDim
					font.pixelSize: Config.fontSize - 1
				}
			}

			// Opens the device picker or the device drawer.
			MouseArea {
				id: more

				Layout.preferredWidth: 26
				Layout.preferredHeight: 26
				visible: root.isStream ? Audio.outputs.length + Audio.inputs.length > 1
					: root.stereo || (root.portInfo?.ports.length ?? 0) > 1 || !root.isDefault
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.open = !root.open

				Rectangle {
					anchors.fill: parent
					radius: 13
					color: root.open ? Qt.alpha(Config.accent, 0.22)
						: more.containsMouse ? Config.bgAlt : "transparent"
				}

				Label {
					anchors.centerIn: parent
					text: root.open ? Config.icons.chevron : Config.icons.chevronRight
					color: root.open ? Config.accent : Config.fgDim
					font.pixelSize: Config.fontSize - 4
				}
			}
		}

		VolumeSlider {
			Layout.fillWidth: true
			value: root.volume
			max: Math.max(root.max, root.reach)
			muted: root.muted
			tone: root.isStream ? Config.blue : Config.accent
			peak: root.level
			onMoved: v => {
				if (!root.audio) return;
				root.audio.muted = false;
				root.audio.volume = v;
			}
		}

		// ---- where an app plays ----
		// Always takes its line on an app's row, linked or not, so the row's
		// height never jumps while Pipewire relinks a stream.
		RowLayout {
			Layout.fillWidth: true
			Layout.preferredHeight: 14
			visible: root.isStream && !root.open
			spacing: 6

			Label {
				text: !root.device ? "Idle"
					: (root.node?.isSink ? "Playing on " : "Recording from ") + Audio.label(root.device)
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 4
				elide: Text.ElideRight
				Layout.fillWidth: true
			}
		}

		Flow {
			Layout.fillWidth: true
			visible: root.isStream && root.open
			spacing: 6

			Label {
				height: 24
				text: root.node?.isSink ? "Play on" : "Record from"
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
			}

			Repeater {
				model: root.node?.isSink ? Audio.outputs : Audio.inputs

				ChipButton {
					required property var modelData

					text: Audio.label(modelData)
					active: modelData === root.device
					onClicked: Audio.moveStream(root.node, modelData)
				}
			}
		}

		// ---- device drawer ----
		ColumnLayout {
			Layout.fillWidth: true
			visible: !root.isStream && (root.open || root.featured)
			spacing: 8

			Flow {
				Layout.fillWidth: true
				visible: (root.portInfo?.ports.length ?? 0) > 1 || (!root.isDefault && !root.featured)
				spacing: 6

				ChipButton {
					visible: !root.isDefault && !root.featured
					glyph: Config.icons.check
					text: "Make default"
					tone: Config.green
					onClicked: root.node.isSink ? Audio.setOutput(root.node) : Audio.setInput(root.node)
				}

				Repeater {
					model: (root.portInfo?.ports.length ?? 0) > 1 ? root.portInfo.ports : []

					ChipButton {
						required property var modelData

						text: modelData.description + (modelData.available ? "" : " (unplugged)")
						dim: !modelData.available
						active: root.portInfo.active === modelData.name
						onClicked: Audio.setPort(root.node, modelData.name)
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true
				visible: root.stereo && (root.open || !root.featured)
				spacing: 8

				Label {
					text: "L"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}

				// Balance, centre-detented: within 5% of the middle is the middle.
				Item {
					id: bal

					Layout.fillWidth: true
					Layout.preferredHeight: 18

					readonly property real value: Audio.balance(root.node)

					function commit(x: real) {
						let b = (x / width) * 2 - 1;
						if (Math.abs(b) < 0.05) b = 0;
						Audio.setBalance(root.node, Math.max(-1, Math.min(1, b)));
					}

					Rectangle {
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width
						height: 4
						radius: 2
						color: Config.bgAlt
					}

					Rectangle {
						anchors.horizontalCenter: parent.horizontalCenter
						anchors.verticalCenter: parent.verticalCenter
						width: 2
						height: 10
						color: Config.fgDim
					}

					Rectangle {
						anchors.verticalCenter: parent.verticalCenter
						x: (bal.value + 1) / 2 * (parent.width - width)
						width: 12
						height: 12
						radius: 6
						color: Config.surface
						border.width: 2
						border.color: Config.accent
					}

					MouseArea {
						anchors.fill: parent
						preventStealing: true
						cursorShape: Qt.PointingHandCursor
						onPressed: event => bal.commit(event.x)
						onPositionChanged: event => { if (pressed) bal.commit(event.x); }
						onDoubleClicked: Audio.setBalance(root.node, 0)
					}
				}

				Label {
					text: "R"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}
			}
		}
	}
}
