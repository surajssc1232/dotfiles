import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.widgets

// The sound mixer, opened by right-clicking the volume pill. Replaces
// pavucontrol: the output in use up top, then tabs for every app playing or
// recording, every output, every input (with a live meter, so the mic can be
// tested by talking), and the sound cards' profiles.
Item {
	id: root

	// Meters and pactl reads only run while this is on screen.
	property bool live: false

	// "apps" | "outputs" | "inputs" | "profiles"
	property string tab: "apps"

	// Past 100% when asked for: some apps and laptop speakers are just quiet.
	property bool boost: false
	Component.onCompleted: root.boost = Persist.get("mixerBoost", false)
	readonly property real max: root.boost ? Config.volumeMax : 1

	readonly property int listMax: 380

	implicitWidth: 460
	implicitHeight: body.implicitHeight

	onLiveChanged: if (live) Audio.refresh()

	ColumnLayout {
		id: body

		anchors.left: parent.left
		anchors.right: parent.right
		spacing: 10

		// ---- title ----
		RowLayout {
			Layout.fillWidth: true
			Layout.leftMargin: 4
			spacing: 8

			Label {
				text: Config.icons.mixer + "  Sound"
				color: Config.accent
			}

			Item { Layout.fillWidth: true }

			ChipButton {
				glyph: Config.icons.up
				text: "Boost to " + Math.round(Config.volumeMax * 100) + "%"
				active: root.boost
				tone: Config.yellow
				onClicked: {
					root.boost = !root.boost;
					Persist.set("mixerBoost", root.boost);
				}
			}
		}

		// ---- the output in use ----
		Group {
			pad: 4

			MixerRow {
				Layout.fillWidth: true
				node: Audio.sink
				visible: Audio.sink !== null
				featured: true
				live: root.live
				max: root.max
			}

			MixerRow {
				Layout.fillWidth: true
				node: Audio.source
				visible: Audio.source !== null
				featured: true
				live: root.live
				max: root.max
			}
		}

		// ---- tabs ----
		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			ChipButton {
				text: "Apps" + (Audio.streams.length + Audio.recorders.length > 0
					? "  " + (Audio.streams.length + Audio.recorders.length) : "")
				active: root.tab === "apps"
				onClicked: root.tab = "apps"
			}
			ChipButton {
				text: "Outputs  " + Audio.outputs.length
				active: root.tab === "outputs"
				onClicked: root.tab = "outputs"
			}
			ChipButton {
				text: "Inputs  " + Audio.inputs.length
				active: root.tab === "inputs"
				onClicked: root.tab = "inputs"
			}
			ChipButton {
				text: "Profiles"
				visible: Audio.cards.length > 0
				active: root.tab === "profiles"
				onClicked: root.tab = "profiles"
			}

			Item { Layout.fillWidth: true }

			// Who has the microphone open, at a glance from any tab.
			Label {
				visible: Audio.recorders.length > 0
				text: Config.icons.mic + " in use"
				color: Config.red
				font.pixelSize: Config.fontSize - 3
			}
		}

		// ---- the tab's list ----
		Flickable {
			id: scroller

			Layout.fillWidth: true
			Layout.preferredHeight: Math.min(root.listMax, list.implicitHeight)
			contentHeight: list.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			ColumnLayout {
				id: list

				width: scroller.width
				spacing: 4

				// Apps playing.
				Repeater {
					model: ScriptModel { values: root.tab === "apps" ? Audio.streams : [] }

					MixerRow {
						required property var modelData
						Layout.fillWidth: true
						node: modelData
						live: root.live
						max: root.max
					}
				}

				Label {
					Layout.fillWidth: true
					Layout.topMargin: 6
					Layout.leftMargin: 8
					visible: root.tab === "apps" && Audio.recorders.length > 0
					text: "RECORDING"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
					font.letterSpacing: 1
				}

				// Apps recording.
				Repeater {
					model: ScriptModel { values: root.tab === "apps" ? Audio.recorders : [] }

					MixerRow {
						required property var modelData
						Layout.fillWidth: true
						node: modelData
						live: root.live
						max: root.max
					}
				}

				Label {
					Layout.fillWidth: true
					Layout.preferredHeight: 60
					horizontalAlignment: Text.AlignHCenter
					visible: root.tab === "apps" && Audio.streams.length + Audio.recorders.length === 0
					text: "No app is playing or recording sound"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
				}

				// Devices.
				Repeater {
					model: ScriptModel {
						values: root.tab === "outputs" ? Audio.outputs
							: root.tab === "inputs" ? Audio.inputs : []
					}

					MixerRow {
						required property var modelData
						Layout.fillWidth: true
						node: modelData
						live: root.live
						max: root.max
					}
				}

				Label {
					Layout.fillWidth: true
					Layout.leftMargin: 8
					visible: root.tab === "inputs" && Audio.inputs.length > 0
					text: "Speak to see the level move; the default mic is outlined."
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
				}

				// Sound cards and their profiles.
				Repeater {
					model: root.tab === "profiles" ? Audio.cards : []

					ColumnLayout {
						id: card

						required property var modelData

						Layout.fillWidth: true
						Layout.margins: 6
						spacing: 6

						Label {
							Layout.fillWidth: true
							text: card.modelData.description
							color: Config.fg
							font.pixelSize: Config.fontSize - 1
							elide: Text.ElideRight
						}

						Repeater {
							model: card.modelData.profiles.filter(p => p.available || p.name === card.modelData.active)

							MouseArea {
								id: prof

								required property var modelData
								readonly property bool active: modelData.name === card.modelData.active

								Layout.fillWidth: true
								Layout.preferredHeight: 28
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: Audio.setProfile(card.modelData.name, modelData.name)

								Rectangle {
									anchors.fill: parent
									radius: Config.radius - 4
									color: prof.active ? Qt.alpha(Config.accent, 0.16)
										: prof.containsMouse ? Config.bgAlt : "transparent"
								}

								RowLayout {
									anchors.fill: parent
									anchors.leftMargin: 10
									anchors.rightMargin: 10
									spacing: 10

									Rectangle {
										Layout.preferredWidth: 12
										Layout.preferredHeight: 12
										radius: 6
										color: "transparent"
										border.width: 2
										border.color: prof.active ? Config.accent : Config.fgDim

										Rectangle {
											anchors.centerIn: parent
											width: 6
											height: 6
											radius: 3
											visible: prof.active
											color: Config.accent
										}
									}

									Label {
										Layout.fillWidth: true
										text: prof.modelData.description
										color: prof.active ? Config.accent : Config.fg
										font.pixelSize: Config.fontSize - 2
										elide: Text.ElideRight
									}
								}
							}
						}
					}
				}
			}
		}

		Label {
			Layout.fillWidth: true
			Layout.leftMargin: 4
			text: "Scroll a slider for 5% steps · ▸ for devices, ports and balance · Esc closes"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 4
			elide: Text.ElideRight
		}
	}
}
