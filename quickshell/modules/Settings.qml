import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.services
import qs.widgets

// Control centre: the distro logo in the bar, opening a grid of tiles whose
// detail panes expand in place below them.
Pill {
	id: root

	readonly property int menuWidth: 520
	readonly property int gap: 6
	// One grid cell's height; the tall tile takes two of them plus the gap.
	readonly property int unit: 54

	// Half the usable width. The top row pins both halves rather than relying
	// on fillWidth: a nested layout does not claim stretch the way a plain
	// tile does, which left the big tile a sliver and its neighbour the rest.
	readonly property real half: (menuWidth - Config.padding - gap) / 2

	readonly property var battery: UPower.displayDevice
	readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : 0
	readonly property bool charging: battery?.state === UPowerDeviceState.Charging
		|| battery?.state === UPowerDeviceState.FullyCharged

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var audio: sink?.audio ?? null
	readonly property real volume: audio?.volume ?? 0
	readonly property bool muted: audio?.muted ?? false

	readonly property var micAudio: Audio.source?.audio ?? null
	readonly property real micVolume: micAudio?.volume ?? 0
	readonly property bool micMuted: micAudio?.muted ?? false

	// Which device list is open, if any: "output" or "input".
	property string devices: ""

	// Which tile's pane is open, if any: "wifi", "bt", "proc", "theme".
	property string pane: ""

	function toggle(id: string) {
		root.pane = root.pane === id ? "" : id;
	}

	// A short delay lets the panel actually leave the screen before the
	// recorder starts, so the first frames are not of the menu.
	function startRecording(geometry: string) {
		if (geometry === "select") regionDelay.restart();
		else fullDelay.restart();
	}

	Timer {
		id: fullDelay
		interval: 250
		onTriggered: Recorder.start("")
	}

	Timer {
		id: regionDelay
		interval: 250
		onTriggered: {
			// slurp draws its own layer-shell selection surface, so it works
			// on any wlroots compositor rather than needing one of its own.
			picker.running = true;
		}
	}

	Process {
		id: picker

		command: ["slurp", "-f", "%x,%y %wx%h"]

		stdout: StdioCollector {
			onStreamFinished: {
				const geometry = text.trim();
				// Empty means the selection was cancelled with Escape.
				if (geometry) Recorder.start(geometry);
			}
		}
	}

	interactive: true
	onClicked: layer.open = !layer.open

	// Keeps the default sink's volume and mute properties bound and live.
	PwObjectTracker {
		objects: root.sink ? [root.sink] : []
	}

	Label {
		text: Config.distroIcon
		color: layer.open ? Config.accent : Config.fg
		font.pixelSize: Config.fontSize + 3
	}

	PopupLayer {
		id: layer

		anchorItem: root
		contentWidth: root.menuWidth
		contentHeight: body.implicitHeight + Config.padding

		// Only while a Wi-Fi password is actually being typed.
		// Focusable for as long as the panel is open rather than only while a
		// field is up. A layer surface is mapped with its keyboard mode already
		// decided, and flipping it afterwards is not something a compositor is
		// obliged to honour — which is why the Wi-Fi password field and the
		// weather city field would appear but refuse to take a keystroke.
		keyboardFocus: layer.open

		onOpenChanged: {
			if (!open) {
				root.pane = "";
				root.devices = "";
			}
			Brightness.active = open;
		}

		// A screenshot keybind can fire while this panel is up. It is captured
		// in the frame either way, but for a region drag it then has to get
		// out of the way: two overlay surfaces would otherwise compete for the
		// pointer, and a click meant to start the selection could land here
		// and dismiss instead. By this point the pixels are already taken.
		Connections {
			target: Shot
			function onFrameReadyChanged() {
				if (Shot.frameReady && Shot.mode === "region") layer.open = false;
			}
		}

		Panel {
			anchors.fill: parent

			ColumnLayout {
				id: body

				anchors.fill: parent
				anchors.margins: Config.padding / 2
				spacing: root.gap

				// ---- header ----
				RowLayout {
					Layout.fillWidth: true
					Layout.leftMargin: 6
					Layout.rightMargin: 4
					Layout.topMargin: 2
					spacing: 8

					Label {
						text: Config.distroIcon
						color: Config.accent
						font.pixelSize: Config.fontSize + 2
					}

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: Config.distroName
						elide: Text.ElideRight
					}
				}

				// ---- tiles ----
				// A bento, not a matrix: tiles take the size their content
				// deserves. Nested row/column layouts rather than a GridLayout
				// with spans, because Qt hands a spanning item's width to one
				// column instead of dividing it, which pushes the grid out of
				// alignment. Every tile has zero implicit width, so fillWidth
				// splits each row into exact equal shares.
				RowLayout {
					Layout.fillWidth: true
					spacing: root.gap

					// Wi-Fi earns the double-height tile: it is the thing most
					// often being checked, and the one with most to say.
					Tile {
						Layout.preferredWidth: root.half
						Layout.preferredHeight: root.unit * 2 + root.gap

						variant: "tall"
						icon: Network.wifiEnabled ? Config.icons.wifi : Config.icons.wifiOff
						label: "Wi-Fi"
						detail: !Network.wifiEnabled ? "Off"
							: Network.connected
								? Network.activeSsid + " · " + Network.activeSignal + "%"
								: "Not connected"
						on: Network.wifiEnabled
						toggleable: true
						expanded: root.pane === "wifi"
						onTriggered: root.toggle("wifi")
						onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
					}

					ColumnLayout {
						Layout.preferredWidth: root.half
						spacing: root.gap

						Tile {
							Layout.fillWidth: true
							Layout.minimumWidth: 0
							Layout.preferredHeight: root.unit

							icon: Config.icons.bluetooth
							label: "Bluetooth"
							detail: !Bt.enabled ? "Off"
								: Bt.connectedDevices.length === 0 ? "No devices"
								: Bt.connectedDevices.length === 1 ? Bt.label(Bt.connectedDevices[0])
								: Bt.connectedDevices.length + " devices"
							on: Bt.enabled
							busy: Bt.busy
							toggleable: true
							visible: Bt.present
							expanded: root.pane === "bt"
							onTriggered: root.toggle("bt")
							onToggled: Bt.setEnabled(!Bt.enabled)
						}

						RowLayout {
							Layout.fillWidth: true
							spacing: root.gap

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								icon: Notifs.dnd ? Config.icons.bellOff : Config.icons.bell
								label: "DND"
								detail: "DND"
								on: Notifs.dnd
								onTriggered: Notifs.toggleDnd()
							}

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								icon: Config.icons.power
								label: "Power"
								detail: "Power"
								expanded: root.pane === "power"
								onTriggered: root.toggle("power")
							}

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								visible: root.battery?.isLaptopBattery ?? false
								icon: root.charging
									? Config.icons.charging
									: Config.icons.battery[Math.min(4, Math.floor(root.batteryPercent / 20))]
								label: "Battery"
								detail: root.batteryPercent + "%"
							}
						}
					}
				}

				PaneSlot {
					shown: root.pane === "wifi" ? wifiPane
						: root.pane === "bt" ? btPane
						: root.pane === "power" ? powerPane : null

					// Kept alive rather than swapped through a Loader: each is idle
					// until its `active` turns on, and a Loader would discard a
					// half-typed password on every switch between panes.
					WifiPanel {
						id: wifiPane
						width: parent.width
						visible: root.pane === "wifi"
						active: visible
					}

					BluetoothPanel {
						id: btPane
						width: parent.width
						visible: root.pane === "bt"
						active: visible
					}

					// Behind a pane rather than on the tile itself: each of
					// these ends the session one way or another, and none of
					// them should sit one stray click away from a mis-aimed
					// press on DND.
					Item {
						id: powerPane

						width: parent.width
						visible: root.pane === "power"
						implicitHeight: powerRow.implicitHeight

						RowLayout {
							id: powerRow

							width: parent.width
							spacing: root.gap

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								icon: Config.icons.lock
								label: "Lock"
								detail: "Lock"
								// The panel steps aside first in every case
								// here: the lock surface and the logout both
								// take the whole screen, and a panel left open
								// behind them is one still open on the way back.
								onTriggered: {
									root.pane = "";
									layer.open = false;
									Lock.lock();
								}
							}

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								icon: Config.icons.disconnect
								label: "Log out"
								detail: "Log out"
								// Ends the systemd session rather than killing
								// the compositor: terminate-user is the fallback
								// for a session id that is not set.
								onTriggered: {
									root.pane = "";
									layer.open = false;
									Quickshell.execDetached({ command: ["sh", "-c",
										'loginctl terminate-session "${XDG_SESSION_ID:-}" '
										+ '|| loginctl terminate-user "$USER"'] });
								}
							}

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								icon: Config.icons.nightLight
								label: "Suspend"
								detail: "Suspend"
								onTriggered: {
									root.pane = "";
									layer.open = false;
									Quickshell.execDetached({ command: ["systemctl", "suspend"] });
								}
							}

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								icon: Config.icons.refresh
								label: "Restart"
								detail: "Restart"
								onTriggered: {
									root.pane = "";
									layer.open = false;
									Quickshell.execDetached({ command: ["systemctl", "reboot"] });
								}
							}

							Tile {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								Layout.preferredHeight: root.unit

								variant: "mini"
								danger: true
								icon: Config.icons.plug
								label: "Shut down"
								detail: "Shut down"
								onTriggered: {
									root.pane = "";
									layer.open = false;
									Quickshell.execDetached({ command: ["systemctl", "poweroff"] });
								}
							}
						}
					}
				}

				// ---- self-contained controls ----
				// Full width, and no detail pane: a slider you can already
				// reach is faster than a menu that hides one.
				SliderTile {
					Layout.fillWidth: true

					icon: root.muted ? Config.icons.volMute
						: root.volume > 0.5 ? Config.icons.volHigh
						: Config.icons.volLow
					label: "Output · " + Audio.label(Audio.sink)
					readout: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
					value: root.volume
					dimmed: root.muted
					visible: root.audio !== null

					expandable: true
					expanded: root.devices === "output"
					onToggled: root.devices = root.devices === "output" ? "" : "output"

					onMoved: value => {
						if (!root.audio) return;
						root.audio.muted = false;
						root.audio.volume = value;
					}
					onIconClicked: if (root.audio) root.audio.muted = !root.audio.muted
				}

				DeviceList {
					Layout.fillWidth: true
					visible: root.devices === "output"
					devices: Audio.outputs
					current: Audio.sink
					emptyText: "No output devices"
					onPicked: device => Audio.setOutput(device)
				}

				SliderTile {
					Layout.fillWidth: true

					icon: root.micMuted ? Config.icons.micOff : Config.icons.mic
					label: "Input · " + Audio.label(Audio.source)
					readout: root.micMuted ? "muted" : Math.round(root.micVolume * 100) + "%"
					value: root.micVolume
					dimmed: root.micMuted
					fill: Config.green
					visible: Audio.source !== null

					expandable: true
					expanded: root.devices === "input"
					onToggled: root.devices = root.devices === "input" ? "" : "input"

					onMoved: value => {
						if (!root.micAudio) return;
						root.micAudio.muted = false;
						root.micAudio.volume = value;
					}
					onIconClicked: if (root.micAudio) root.micAudio.muted = !root.micAudio.muted
				}

				DeviceList {
					Layout.fillWidth: true
					visible: root.devices === "input"
					devices: Audio.inputs
					current: Audio.source
					emptyText: "No input devices"
					onPicked: device => Audio.setInput(device)
				}

				// ---- per-application volume ----
				// Only present while something is playing: a section that is
				// permanently empty is worse than one that appears when it
				// has something to say.
				Label {
					Layout.fillWidth: true
					Layout.leftMargin: 4
					Layout.topMargin: 2
					visible: Audio.streams.length > 0
					text: "Applications"
					color: Config.accent
					font.pixelSize: Config.fontSize - 2
				}

				Repeater {
					model: Audio.streams

					SliderTile {
						required property var modelData

						Layout.fillWidth: true

						icon: (modelData.audio?.muted ?? false)
							? Config.icons.volMute : Config.icons.mixer
						label: Audio.streamLabel(modelData)
						readout: (modelData.audio?.muted ?? false) ? "muted"
							: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
						value: modelData.audio?.volume ?? 0
						dimmed: modelData.audio?.muted ?? false
						fill: Config.blue

						onMoved: value => {
							if (!modelData.audio) return;
							modelData.audio.muted = false;
							modelData.audio.volume = value;
						}
						onIconClicked: if (modelData.audio)
							modelData.audio.muted = !modelData.audio.muted
					}
				}

				SliderTile {
					Layout.fillWidth: true

					icon: Config.icons.brightness
					label: "Brightness"
					readout: Brightness.percent + "%"
					value: Brightness.percent / 100
					fill: Config.yellow
					visible: Brightness.available

					// Never all the way to zero: a black screen with no
					// backlight key is hard to recover from.
					onMoved: value => Brightness.set(Math.max(1, value * 100))
				}

				RowLayout {
					Layout.fillWidth: true
					spacing: root.gap

					Tile {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						Layout.preferredHeight: root.unit

						icon: Config.icons.nightLight
						label: "Night light"
						detail: NightLight.enabled
							? NightLight.temperature + "K" : "Off"
						on: NightLight.enabled
						toggleable: true
						onTriggered: NightLight.toggle()
						onToggled: NightLight.toggle()
					}

					Tile {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						Layout.preferredHeight: root.unit

						icon: Config.icons.image
						label: "Wallpaper"
						detail: Wallpaper.current
							? Wallpaper.current.split("/").pop()
							: "None"
						expanded: root.pane === "wall"
						onTriggered: root.toggle("wall")
					}

				}

				PaneSlot {
					shown: root.pane === "wall" ? wallPane : null

					WallpaperPanel {
						id: wallPane
						width: parent.width
						visible: root.pane === "wall"
						active: visible
					}
				}

				RowLayout {
					Layout.fillWidth: true
					spacing: root.gap

					Tile {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						Layout.preferredHeight: root.unit

						icon: Config.icons.video
						label: Recorder.recording ? "Recording" : "Record"
						detail: Recorder.recording ? Recorder.clock() : Recorder.audioLabel
						on: Recorder.recording
						expanded: root.pane === "rec"
						onTriggered: {
							if (Recorder.recording) Recorder.stop();
							else root.toggle("rec");
						}
					}

					Tile {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						Layout.preferredHeight: root.unit

						icon: Config.icons.cpu
						label: "Processes"
						// Deliberately not a live figure: the pane only samples
						// while it is open, so anything numeric here would sit
						// frozen at its last value pretending to be current.
						detail: "Top by usage"
						expanded: root.pane === "proc"
						onTriggered: root.toggle("proc")
					}

				}

				PaneSlot {
					shown: root.pane === "rec" ? recPane
						: root.pane === "proc" ? procPane : null

					RecorderPanel {
						id: recPane
						width: parent.width
						visible: root.pane === "rec"
						// Recording the control centre on top of everything is
						// almost never wanted, so it steps aside first.
						onRequested: geometry => {
							layer.open = false;
							root.startRecording(geometry);
						}
					}

					ProcessList {
						id: procPane
						width: parent.width
						visible: root.pane === "proc"
						active: visible
						framed: false
						rows: 9
					}
				}

				Tile {
					Layout.fillWidth: true
					Layout.preferredHeight: root.unit

					icon: Config.icons.palette
					label: "Colorscheme"
					detail: Config.theme.name
					expanded: root.pane === "theme"
					onTriggered: root.toggle("theme")
				}

				PaneSlot {
					shown: root.pane === "theme" ? themePane : null

					ThemePanel {
						id: themePane
						width: parent.width
						visible: root.pane === "theme"
						active: visible
					}
				}


			}
		}
	}

	// One detail pane, opening directly beneath the tiles that own it.
	//
	// A section that expands belongs next to the control that expanded it: a
	// single pane at the foot of the panel meant clicking Wi-Fi scrolled your
	// eye past everything else to find what had opened.
	component PaneSlot: ColumnLayout {
		id: slot

		property Item shown: null
		default property alias content: holder.data

		Layout.fillWidth: true
		spacing: 0
		// Hidden rather than merely empty when nothing is open, so the parent
		// layout drops its spacing too and closed slots take no room at all.
		visible: slot.shown !== null

		Rectangle {
			Layout.fillWidth: true
			Layout.topMargin: 2
			Layout.bottomMargin: 6
			Layout.preferredHeight: 1
			color: Config.border
		}

		Item {
			id: holder

			Layout.fillWidth: true
			Layout.preferredHeight: slot.shown ? slot.shown.implicitHeight : 0
		}
	}
}
