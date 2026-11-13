import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.services
import qs.widgets

// Control centre: the distro logo in the bar, opening two columns of cards
// whose detail panes expand in place below the tiles that own them.
//
// The header says who and what this machine is. Under it, the left column is
// everything you switch or open — connections, then the desktop's own
// furniture — and the right is everything you slide: sound and the display.
Pill {
	id: root

	readonly property int menuWidth: 800
	readonly property int gap: 8
	// One row of tiles.
	readonly property int unit: 58

	// The two columns are pinned to exact halves rather than left to
	// fillWidth: a nested layout does not claim stretch the way a plain tile
	// does, so the column with the wider content would take the difference.
	readonly property real column: (menuWidth - Config.inset * 2 - gap) / 2

	readonly property var battery: UPower.displayDevice
	readonly property bool hasBattery: battery?.isLaptopBattery ?? false
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

	// Which pane is open, if any: "power", "wifi", "bt", "wall", "theme",
	// "rec" or "proc". One at a time, so the panel never grows by two.
	property string pane: ""

	function toggle(id: string) {
		root.pane = root.pane === id ? "" : id;
	}

	// Everything that leaves the panel behind goes through here: a lock
	// surface, a logout and another overlay all take the screen, and a panel
	// left open behind them is one still open on the way back.
	function dismiss() {
		root.pane = "";
		layer.open = false;
	}

	// ---- header facts ----
	readonly property string user: Quickshell.env("USER") || "user"
	property string host: ""
	property string uptime: ""

	FileView {
		id: hostFile

		path: "/proc/sys/kernel/hostname"
		blockLoading: true
		printErrors: false
	}

	FileView {
		id: uptimeFile

		path: "/proc/uptime"
		blockLoading: true
		printErrors: false
	}

	function readUptime() {
		uptimeFile.reload();
		const secs = parseFloat(uptimeFile.text()) || 0;
		if (secs <= 0) {
			root.uptime = "";
			return;
		}
		const days = Math.floor(secs / 86400);
		const hours = Math.floor((secs % 86400) / 3600);
		const mins = Math.floor((secs % 3600) / 60);
		root.uptime = days > 0 ? days + "d " + hours + "h"
			: hours > 0 ? hours + "h " + mins + "m"
			: mins + "m";
	}

	// Only while it can be read. A minute is the finest the readout goes.
	Timer {
		interval: 60000
		repeat: true
		running: layer.open
		triggeredOnStart: true
		onTriggered: root.readUptime()
	}

	Component.onCompleted: root.host = hostFile.text().trim()

	// Time left or time to full, in the shortest form that still reads. UPower
	// reports 0 while it has no estimate, and then there is nothing to add to
	// the percentage.
	function batteryTime(): string {
		if (!root.battery) return "";
		if (root.battery.state === UPowerDeviceState.FullyCharged) return "full";
		const secs = root.charging ? root.battery.timeToFull : root.battery.timeToEmpty;
		if (!secs || secs <= 0) return "";
		const hours = Math.floor(secs / 3600);
		const mins = Math.round((secs % 3600) / 60);
		return hours > 0 ? hours + "h " + mins + "m" : mins + "m";
	}

	// ---- airplane mode ----
	// Not a mode of its own: it is every radio being off, however that came
	// about, so the tile cannot disagree with the two above it.
	readonly property bool airplane: !Network.wifiEnabled && !(Bt.present && Bt.enabled)

	// What it switched off, so leaving brings back those and not a radio that
	// was already off for some other reason.
	property bool airWifi: false
	property bool airBt: false

	function toggleAirplane() {
		if (root.airplane) {
			// Radios turned off by hand leave nothing recorded; Wi-Fi is then
			// the one to bring back, since that is what "online" means here.
			if (root.airWifi || !root.airBt) Network.setWifiEnabled(true);
			if (root.airBt) Bt.setEnabled(true);
			root.airWifi = false;
			root.airBt = false;
			return;
		}
		root.airWifi = Network.wifiEnabled;
		root.airBt = Bt.present && Bt.enabled;
		if (root.airWifi) Network.setWifiEnabled(false);
		if (root.airBt) Bt.setEnabled(false);
	}

	// ---- power profile ----
	function cycleProfile() {
		const all = Power.profiles;
		if (all.length === 0) return;
		Power.set(all[(all.indexOf(Power.profile) + 1) % all.length]);
	}

	// ---- keyboard navigation ----
	// The control the keyboard cursor is on, or null before the first keypress.
	property Item cur: null

	// Down the left column, then down the right. Anything hidden drops out, so the cursor never lands
	// on a tile that is not there — which is also how the session row joins
	// in only while its pane is open.
	function navItems(): var {
		const list = [lockButton, powerButton,
			suspendTile, logoutTile, restartTile, shutdownTile,
			wifiTile, btTile, dndTile, airTile, profileTile,
			wallTile, themeTile, recTile, procTile,
			clipTile, storageTile, lyricsTile, inboxTile,
			nowPlaying, outSlider, inSlider];
		for (let i = 0; i < streams.count; i++) list.push(streams.itemAt(i));
		list.push(brightSlider, monitorSlider, nightSlider);
		return list.filter(item => item && item.visible);
	}

	function move(dir: int) {
		const list = root.navItems();
		if (list.length === 0) return;
		let i = list.indexOf(root.cur);
		if (i >= 0) i = (i + dir + list.length) % list.length;
		// The first press lands on Wi-Fi rather than the header: the buttons
		// up there lock the screen and end the session, which is not where a
		// cursor should start.
		else i = dir > 0 ? Math.max(0, list.indexOf(wifiTile)) : list.length - 1;
		root.cur = list[i];
		root.reveal(root.cur, root.cur);
	}

	// Left and right steer a slider or a stepper; on a tile they just move along.
	function adjust(dir: int) {
		if (root.cur && root.cur.scrollBy) root.cur.scrollBy(dir);
		else if (root.cur && root.cur.stepper) root.cur.stepped(dir);
		else root.move(dir);
	}

	// Enter flips a switch where there is one and otherwise opens the tile;
	// Shift+Enter always opens its pane. On a slider, Space mutes and Enter
	// reveals its device list.
	function activate(open: bool) {
		const item = root.cur;
		if (!item) return;
		if (item.scrollBy) {
			if (open || !item.expandable) item.iconClicked();
			else item.toggled();
		} else if (open || !item.toggleable) {
			item.triggered();
		} else {
			item.toggled();
		}
	}

	// ---- scrolling ----
	// With a pane open the panel can want more height than the screen has. It
	// stops at the screen's edge and scrolls instead, and whatever was just
	// opened or moved onto is brought into view.
	function reveal(first: Item, last: Item) {
		if (!first || !last || !layer.capped) return;

		const view = layer.contentHeight - Config.inset * 2;
		const top = first.mapToItem(body, 0, 0).y;
		const bottom = last.mapToItem(body, 0, 0).y + last.height;

		let y = flick.contentY;
		if (bottom > y + view) y = bottom - view;
		// Checked second, so when both cannot fit it is the top that wins: a
		// pane cut off at the bottom reads as "scroll for more", one cut off
		// at the top just looks broken.
		if (top < y) y = top;

		scroller.to = Math.max(0, Math.min(body.implicitHeight - view, y));
		scroller.restart();
	}

	readonly property var paneOwners: ({
		"power": [powerButton, powerSlot],
		"wifi": [wifiTile, linkSlot],
		"bt": [btTile, linkSlot],
		"wall": [wallTile, lookSlot],
		"theme": [themeTile, lookSlot],
		"rec": [recTile, toolSlot],
		"proc": [procTile, toolSlot]
	})

	// A layout places its children when it is polished, not when the property
	// that changed them is set, so the pane has no position to scroll to yet.
	onPaneChanged: if (root.pane !== "") settle.restart()
	onDevicesChanged: if (root.devices !== "") settle.restart()

	Timer {
		id: settle

		interval: 60
		onTriggered: {
			if (root.devices === "output") root.reveal(outSlider, outDevices);
			else if (root.devices === "input") root.reveal(inSlider, inDevices);

			const owners = root.paneOwners[root.pane];
			if (owners) root.reveal(owners[0], owners[1]);
		}
	}

	// ---- recording ----
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
			//
			// Its default is a 25% white wash, which over anything bright —
			// a video, a white page — is close enough to invisible that the
			// selection looks like it never opened. Dimmed instead, with the
			// border in the theme's accent and the size shown while dragging.
			//
			// stdin is pointed at /dev/null: when it is not a terminal, slurp
			// first reads a list of predefined boxes from it and shows nothing
			// until that input ends. A Process's stdin is an open pipe that
			// never ends, so slurp would sit there forever with no surface.
			const accent = String(Config.accent).replace("#", "").slice(-6);
			picker.command = ["sh", "-c", 'exec slurp "$@" < /dev/null', "sh", "-d",
				"-b", "#00000088",
				"-c", "#" + accent + "ff",
				"-s", "#00000000",
				"-w", "2",
				"-f", "%x,%y %wx%h"];
			picker.running = true;
		}
	}

	Process {
		id: picker

		stdout: StdioCollector {
			id: pickerOut
		}

		stderr: StdioCollector {
			id: pickerErr
		}

		// Decided on exit rather than when stdout closes, so the exit code
		// is known: slurp exits 1 with "selection cancelled" on Escape,
		// which is not an error, and anything else is.
		onExited: code => {
			const geometry = pickerOut.text.trim();
			if (code === 0 && geometry) {
				Recorder.start(geometry);
				return;
			}

			// Cancelled with Escape, or killed from outside (a signal leaves
			// no message): neither is something to report.
			const why = pickerErr.text.trim();
			if (!why || /cancel/i.test(why)) return;

			Quickshell.execDetached({
				command: ["notify-send", "-a", "Recorder", "-u", "critical",
					"Region selection failed",
					why]
			});
		}
	}

	interactive: true
	onClicked: layer.open = !layer.open

	IpcHandler {
		target: "settings"

		function toggle(): void {
			layer.open = !layer.open;
		}

		function open(): void {
			layer.open = true;
		}

		function close(): void {
			layer.open = false;
		}

		function isOpen(): bool {
			return layer.open;
		}
	}

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

		// As tall as its content wants, up to what fits under the bar with
		// the same margin below as the bar keeps above.
		readonly property int wanted: body.implicitHeight + Config.inset * 2
		readonly property int room: (layer.screen?.height ?? 1080)
			- Config.barHeight - Config.barMargin * 3
		readonly property bool capped: wanted > room

		anchorItem: root
		contentWidth: root.menuWidth
		contentHeight: Math.min(wanted, room)

		// Focusable for as long as the panel is open rather than only while a
		// field is up. A layer surface is mapped with its keyboard mode already
		// decided, and flipping it afterwards is not something a compositor is
		// obliged to honour — which is why the Wi-Fi password field and the
		// weather city field would appear but refuse to take a keystroke.
		keyboardFocus: layer.open

		onOpenChanged: {
			if (open) {
				keyNav.forceActiveFocus();
				// The radio and the profile can both change behind the
				// shell's back; the tiles should not open on a stale answer.
				Network.refresh();
				Power.refresh();
			} else {
				root.pane = "";
				root.devices = "";
				root.cur = null;
				flick.contentY = 0;
			}
			Brightness.active = open;
			MonitorBrightness.active = open;
			Power.active = open;
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

		Item {
			id: keyNav

			focus: true
			Keys.onPressed: event => {
				const k = event.key;
				const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
				event.accepted = true;
				if (k === Qt.Key_Down || k === Qt.Key_J || (k === Qt.Key_Tab && !shift)) root.move(1);
				else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab
					|| (k === Qt.Key_Tab && shift)) root.move(-1);
				else if (k === Qt.Key_Right || k === Qt.Key_L) root.adjust(1);
				else if (k === Qt.Key_Left || k === Qt.Key_H) root.adjust(-1);
				else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.activate(shift);
				else if (k === Qt.Key_Space) root.activate(root.cur?.scrollBy !== undefined);
				else event.accepted = false;
			}
		}

		Panel {
			anchors.fill: parent

			Flickable {
				id: flick

				anchors.fill: parent
				anchors.margins: Config.inset

				contentHeight: body.implicitHeight
				// Clipped even when nothing scrolls: the panel grows towards a
				// newly opened pane over a few frames, and until it arrives the
				// pane would otherwise hang out below its bottom edge.
				clip: true
				interactive: layer.capped
				boundsBehavior: Flickable.StopAtBounds
				flickDeceleration: 6000

				NumberAnimation {
					id: scroller

					target: flick
					property: "contentY"
					duration: Config.animMed
					easing.type: Easing.OutQuint
				}

				ColumnLayout {
					id: body

					width: flick.width
					spacing: root.gap

					// ---- header ----
					// Indented by a card's padding, so the badge starts on the
					// same line as the tiles inside the cards below it.
					RowLayout {
						Layout.fillWidth: true
						Layout.leftMargin: root.gap
						Layout.rightMargin: root.gap
						Layout.topMargin: 2
						Layout.bottomMargin: 2
						spacing: 10

						Rectangle {
							Layout.preferredWidth: 40
							Layout.preferredHeight: 40
							radius: Config.radius - 2
							color: Qt.alpha(Config.accent, 0.18)

							Label {
								anchors.centerIn: parent
								text: Config.distroIcon
								color: Config.accent
								font.pixelSize: Config.fontSize + 7
							}
						}

						ColumnLayout {
							Layout.fillWidth: true
							Layout.minimumWidth: 0
							spacing: 1

							Label {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								text: root.host ? root.user + "@" + root.host : root.user
								font.pixelSize: Config.fontSize + 1
								elide: Text.ElideRight
							}

							Label {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								text: root.uptime
									? Config.distroName + " · up " + root.uptime
									: Config.distroName
								color: Config.fgDim
								font.pixelSize: Config.fontSize - 3
								elide: Text.ElideRight
							}
						}

						RowLayout {
							spacing: 6

							// A readout, not a button: the bar's own battery pill
							// is where its menu lives.
							Rectangle {
								Layout.preferredWidth: chip.implicitWidth + 22
								Layout.preferredHeight: 34
								visible: root.hasBattery
								radius: Config.radius - 2
								color: Config.bgAlt

								RowLayout {
									id: chip

									anchors.centerIn: parent
									spacing: 6

									Label {
										text: root.charging
											? Config.icons.charging
											: Config.icons.battery[Math.min(4, Math.floor(root.batteryPercent / 20))]
										color: root.charging ? Config.green
											: root.batteryPercent <= 15 ? Config.red
											: root.batteryPercent <= 30 ? Config.yellow
											: Config.fg
										font.pixelSize: Config.fontSize - 1
									}

									Label {
										text: root.batteryPercent + "%"
										font.pixelSize: Config.fontSize - 2
									}

									Label {
										visible: text !== ""
										text: root.batteryTime()
										color: Config.fgDim
										font.pixelSize: Config.fontSize - 3
									}
								}
							}

							HeadButton {
								id: lockButton

								icon: Config.icons.lock
								focused: root.cur === lockButton
								onTriggered: {
									root.dismiss();
									Lock.lock();
								}
							}

							HeadButton {
								id: powerButton

								icon: Config.icons.power
								active: root.pane === "power"
								focused: root.cur === powerButton
								onTriggered: root.toggle("power")
							}
						}
					}

					// Behind a button rather than always on show: each of these
					// ends the session one way or another, and none of them
					// should sit one stray click away from a mis-aimed press.
					PaneSlot {
						id: powerSlot

						shown: root.pane === "power" ? powerPane : null

						RowLayout {
							id: powerPane

							width: parent.width
							spacing: root.gap
							visible: root.pane === "power"

							SessionTile {
								id: suspendTile

								icon: Config.icons.sleep
								name: "Suspend"
								onConfirmed: Quickshell.execDetached({ command: ["systemctl", "suspend"] })
							}

							// Ends the systemd session rather than killing the
							// compositor: terminate-user is the fallback for a
							// session id that is not set.
							SessionTile {
								id: logoutTile

								icon: Config.icons.logout
								name: "Log out"
								confirm: true
								onConfirmed: Quickshell.execDetached({ command: ["sh", "-c",
									'loginctl terminate-session "${XDG_SESSION_ID:-}" '
									+ '|| loginctl terminate-user "$USER"'] })
							}

							SessionTile {
								id: restartTile

								icon: Config.icons.refresh
								name: "Restart"
								confirm: true
								onConfirmed: Quickshell.execDetached({ command: ["systemctl", "reboot"] })
							}

							SessionTile {
								id: shutdownTile

								icon: Config.icons.power
								name: "Shut down"
								confirm: true
								risky: true
								onConfirmed: Quickshell.execDetached({ command: ["systemctl", "poweroff"] })
							}
						}
					}

					// ---- two columns ----
					// Side by side rather than one long list: the panel was
					// taller than it was useful, and most of a screen is
					// width. What you switch sits on the left, what you slide
					// on the right. Each column's last card takes up whatever
					// the other column is taller by, so the two always end on
					// the same line.
					RowLayout {
						Layout.fillWidth: true
						spacing: root.gap

						ColumnLayout {
							Layout.preferredWidth: root.column
							Layout.fillHeight: true
							spacing: root.gap

							// ---- connections ----
							// Rows rather than a bento: at half the panel's width a
							// tile beside another has no room left for an SSID or a
							// device name, and those are the reason to look here.
							Group {
								Tile {
									id: wifiTile

									Layout.fillWidth: true
									Layout.preferredHeight: root.unit

									icon: Network.wifiEnabled ? Config.icons.wifi : Config.icons.wifiOff
									label: "Wi-Fi"
									detail: !Network.wifiEnabled ? "Off"
										: Network.connected
											? Network.activeSsid + " \u00b7 " + Network.activeSignal + "%"
											: "Not connected"
									on: Network.wifiEnabled
									toggleable: true
									focused: root.cur === wifiTile
									expanded: root.pane === "wifi"
									onTriggered: root.toggle("wifi")
									onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
								}

								Tile {
									id: btTile

									Layout.fillWidth: true
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
									focused: root.cur === btTile
									expanded: root.pane === "bt"
									onTriggered: root.toggle("bt")
									onToggled: Bt.setEnabled(!Bt.enabled)
								}

								PaneSlot {
									id: linkSlot

									color: Config.surface
									shown: root.pane === "wifi" ? wifiPane
										: root.pane === "bt" ? btPane : null

									// Kept alive rather than swapped through a Loader: each
									// is idle until its `active` turns on, and a Loader
									// would discard a half-typed password on every switch
									// between panes.
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
								}

								RowLayout {
									Layout.fillWidth: true
									spacing: root.gap

									MiniTile {
										id: dndTile

										icon: Notifs.dnd ? Config.icons.bellOff : Config.icons.bell
										label: "DND"
										on: Notifs.dnd
										focused: root.cur === dndTile
										onTriggered: Notifs.toggleDnd()
									}

									MiniTile {
										id: airTile

										icon: Config.icons.plane
										label: "Airplane"
										on: root.airplane
										focused: root.cur === airTile
										onTriggered: root.toggleAirplane()
									}

									// Lit whenever it is not the default, in either
									// direction: both are states worth noticing you
									// were left in.
									MiniTile {
										id: profileTile

										visible: Power.available
										icon: Power.icon(Power.profile)
										label: Power.title(Power.profile)
										on: Power.profile !== "balanced" && Power.profile !== ""
										focused: root.cur === profileTile
										onTriggered: root.cycleProfile()
									}
								}
							}

							// ---- desktop ----
							// Each pair of tiles shares the slot beneath it, so a pane
							// always opens directly under the row that owns it.
							Group {
								title: "Desktop"
								Layout.fillHeight: true

								RowLayout {
									Layout.fillWidth: true
									spacing: root.gap

									Tile {
										id: wallTile

										Layout.fillWidth: true
										Layout.minimumWidth: 0
										Layout.preferredHeight: root.unit

										icon: Config.icons.image
										label: "Wallpaper"
										detail: Wallpaper.current
											? Wallpaper.current.split("/").pop()
											: "None"
										focused: root.cur === wallTile
										expanded: root.pane === "wall"
										onTriggered: root.toggle("wall")
									}

									Tile {
										id: themeTile

										Layout.fillWidth: true
										Layout.minimumWidth: 0
										Layout.preferredHeight: root.unit

										icon: Config.icons.palette
										label: "Colorscheme"
										detail: Config.theme.name
										focused: root.cur === themeTile
										expanded: root.pane === "theme"
										onTriggered: root.toggle("theme")
									}
								}

								PaneSlot {
									id: lookSlot

									color: Config.surface
									shown: root.pane === "wall" ? wallPane
										: root.pane === "theme" ? themePane : null

									WallpaperPanel {
										id: wallPane
										width: parent.width
										visible: root.pane === "wall"
										active: visible
									}

									ThemePanel {
										id: themePane
										width: parent.width
										visible: root.pane === "theme"
										active: visible
									}
								}

								RowLayout {
									Layout.fillWidth: true
									spacing: root.gap

									Tile {
										id: recTile

										Layout.fillWidth: true
										Layout.minimumWidth: 0
										Layout.preferredHeight: root.unit

										icon: Recorder.recording ? Config.icons.stop : Config.icons.video
										label: Recorder.recording ? "Recording" : "Record"
										detail: Recorder.recording ? Recorder.clock() : Recorder.audioLabel
										on: Recorder.recording
										focused: root.cur === recTile
										expanded: root.pane === "rec"
										onTriggered: {
											if (Recorder.recording) Recorder.stop();
											else root.toggle("rec");
										}
									}

									Tile {
										id: procTile

										Layout.fillWidth: true
										Layout.minimumWidth: 0
										Layout.preferredHeight: root.unit

										icon: Config.icons.cpu
										label: "Processes"
										// Deliberately not a live figure: the pane only
										// samples while it is open, so anything numeric
										// here would sit frozen at its last value
										// pretending to be current.
										detail: "Top by usage"
										focused: root.cur === procTile
										expanded: root.pane === "proc"
										onTriggered: root.toggle("proc")
									}
								}

								PaneSlot {
									id: toolSlot

									color: Config.surface
									shown: root.pane === "rec" ? recPane
										: root.pane === "proc" ? procPane : null

									RecorderPanel {
										id: recPane
										width: parent.width
										visible: root.pane === "rec"
										// Recording the control centre on top of everything
										// is almost never wanted, so it steps aside first.
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

								// ---- the shell's other panels ----
								// Each of these has a keybind and nothing on screen that
								// says so. This is where they can be found without
								// remembering one.
								RowLayout {
									Layout.fillWidth: true
									spacing: root.gap

									// The first to give when the other column is
									// the taller one: these are square already,
									// and a little more height suits them. Past
									// that the slack is left empty below.
									Layout.fillHeight: true
									Layout.minimumHeight: root.unit
									Layout.maximumHeight: root.unit + 30

									MiniTile {
										id: clipTile

										Layout.fillHeight: true

										visible: Config.clipboardHistory
										icon: Config.icons.clipboard
										label: "Clipboard"
										focused: root.cur === clipTile
										onTriggered: {
											root.dismiss();
											Clipboard.show();
										}
									}

									MiniTile {
										id: storageTile

										Layout.fillHeight: true

										icon: Config.icons.disk
										label: "Storage"
										focused: root.cur === storageTile
										onTriggered: {
											root.dismiss();
											Storage.show();
										}
									}

									MiniTile {
										id: lyricsTile

										Layout.fillHeight: true

										visible: Config.lyrics
										icon: Config.icons.music
										label: "Lyrics"
										on: Lyrics.shown
										focused: root.cur === lyricsTile
										onTriggered: Lyrics.toggle()
									}

									MiniTile {
										id: inboxTile

										Layout.fillHeight: true

										icon: Config.icons.inbox
										label: Notifs.count > 0 ? "Inbox · " + Notifs.count : "Inbox"
										focused: root.cur === inboxTile
										onTriggered: {
											root.dismiss();
											Notifs.centerToggled();
										}
									}
								}

								Slack {}
							}
						}

						ColumnLayout {
							Layout.preferredWidth: root.column
							Layout.fillHeight: true
							spacing: root.gap

							// ---- sound ----
							// Full-width sliders, and no detail pane: a slider you can
							// already reach is faster than a menu that hides one.
							Group {
								title: "Sound"
								// Asked of the sources rather than of the rows' own
								// `visible`: that is false for everything inside a
								// hidden card, so a card hidden once on their say-so
								// could never come back.
								visible: nowPlaying.player !== null || root.audio !== null
									|| Audio.source !== null

								NowPlaying {
									id: nowPlaying

									Layout.fillWidth: true
									focused: root.cur === nowPlaying
								}

								SliderTile {
									id: outSlider

									Layout.fillWidth: true

									icon: root.muted ? Config.icons.volMute
										: root.volume > 0.5 ? Config.icons.volHigh
										: Config.icons.volLow
									label: "Output · " + Audio.label(Audio.sink)
									readout: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
									value: root.volume
									// Past 100% here and in the launcher; the bar pill stops there.
									scrollMax: Config.volumeMax
									dimmed: root.muted
									visible: root.audio !== null
									focused: root.cur === outSlider

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
									id: outDevices

									Layout.fillWidth: true
									visible: root.devices === "output"
									devices: Audio.outputs
									current: Audio.sink
									emptyText: "No output devices"
									onPicked: device => Audio.setOutput(device)
								}

								SliderTile {
									id: inSlider

									Layout.fillWidth: true

									icon: root.micMuted ? Config.icons.micOff : Config.icons.mic
									label: "Input · " + Audio.label(Audio.source)
									readout: root.micMuted ? "muted" : Math.round(root.micVolume * 100) + "%"
									value: root.micVolume
									dimmed: root.micMuted
									fill: Config.green
									visible: Audio.source !== null
									focused: root.cur === inSlider

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
									id: inDevices

									Layout.fillWidth: true
									visible: root.devices === "input"
									devices: Audio.inputs
									current: Audio.source
									emptyText: "No input devices"
									onPicked: device => Audio.setInput(device)
								}

								// ---- per-application volume ----
								// Only present while something is playing: a section
								// that is permanently empty is worse than one that
								// appears when it has something to say.
								Label {
									Layout.fillWidth: true
									Layout.leftMargin: 6
									Layout.topMargin: 2
									visible: Audio.streams.length > 0
									text: "Applications"
									color: Config.fgDim
									font.pixelSize: Config.fontSize - 3
								}

								Repeater {
									id: streams

									model: Audio.streams

									SliderTile {
										id: stream

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
										focused: root.cur === stream

										onMoved: value => {
											if (!modelData.audio) return;
											modelData.audio.muted = false;
											modelData.audio.volume = value;
										}
										onIconClicked: if (modelData.audio)
											modelData.audio.muted = !modelData.audio.muted
									}
								}
							}

							// ---- display ----
							Group {
								title: "Display"
								Layout.fillHeight: true

								SliderTile {
									id: brightSlider

									Layout.fillWidth: true

									icon: Config.icons.brightness
									// Only told apart when there are two of them.
									label: MonitorBrightness.available ? "Built-in display" : "Brightness"
									readout: Brightness.percent + "%"
									value: Brightness.percent / 100
									fill: Config.yellow
									visible: Brightness.available
									focused: root.cur === brightSlider

									// Never all the way to zero: a black screen with no
									// backlight key is hard to recover from.
									onMoved: value => Brightness.set(Math.max(1, value * 100))
								}

								SliderTile {
									id: monitorSlider

									Layout.fillWidth: true

									icon: Config.icons.display
									label: Brightness.available ? "External monitor" : "Brightness"
									readout: MonitorBrightness.percent + "%"
									value: MonitorBrightness.percent / 100
									fill: Config.yellow
									visible: MonitorBrightness.available
									focused: root.cur === monitorSlider

									onMoved: value => MonitorBrightness.set(value * 100)
								}

								// A slider like its neighbours rather than a tile with
								// plus and minus: it is a level on the same display, and
								// the badge is the switch the way it is the mute for
								// sound. Further right is warmer, so the bar fills as the
								// effect grows instead of as the kelvin figure does.
								SliderTile {
									id: nightSlider

									readonly property int span: Config.nightTempMax - Config.nightTempMin

									Layout.fillWidth: true

									icon: Config.icons.nightLight
									label: "Night light"
									readout: NightLight.enabled ? NightLight.temperature + "K" : "off"
									value: (Config.nightTempMax - NightLight.temperature) / span
									step: Config.nightTempStep / span
									dimmed: !NightLight.enabled
									fill: Qt.tint(Config.yellow, Qt.alpha(Config.red, 0.45))
									focused: root.cur === nightSlider

									// Setting a warmth is asking for it to be on.
									onMoved: value => {
										NightLight.setTemperature(Config.nightTempMax - value * span);
										NightLight.setEnabled(true);
									}
									onIconClicked: NightLight.toggle()
								}

								Slack {}
							}
						}
					}
				}
			}

			// Says there is more, and how far through it you are. Only while the
			// panel has actually hit the screen's edge: mid-animation the content
			// is briefly taller than the panel too, and a bar flashing up for
			// those few frames would be noise.
			Rectangle {
				anchors.right: parent.right
				anchors.rightMargin: 4
				y: flick.y + flick.visibleArea.yPosition * flick.height
				width: 3
				height: flick.visibleArea.heightRatio * flick.height
				radius: 2
				color: Config.fgDim
				opacity: layer.capped ? 0.55 : 0

				Behavior on opacity {
					NumberAnimation { duration: Config.animFast }
				}
			}
		}
	}

	// One detail pane, opening directly beneath the tiles that own it.
	//
	// A section that expands belongs next to the control that expanded it: a
	// single pane at the foot of the panel meant clicking Wi-Fi scrolled your
	// eye past everything else to find what had opened.
	component PaneSlot: Rectangle {
		id: slot

		property Item shown: null
		default property alias content: holder.data

		Layout.fillWidth: true
		// Hidden rather than merely empty when nothing is open, so the parent
		// layout drops its spacing too and closed slots take no room at all.
		visible: slot.shown !== null
		implicitHeight: slot.shown ? slot.shown.implicitHeight + 20 : 0
		radius: Config.radius
		color: Config.surfaceGroup

		Item {
			id: holder

			anchors.fill: parent
			anchors.margins: 10
		}
	}

	// Takes up whatever height a card was stretched by, so its rows stay
	// together at the top instead of being spread out to fill it. The margin
	// cancels the spacing it would otherwise add when there is nothing to take.
	component Slack: Item {
		Layout.fillHeight: true
		Layout.topMargin: -root.gap
	}

	// A single-cell tile, sized for a row of them.
	component MiniTile: Tile {
		Layout.fillWidth: true
		Layout.minimumWidth: 0
		Layout.preferredHeight: root.unit

		variant: "mini"
	}

	// One way of ending the session. Anything that throws away what is open
	// asks twice: the first press arms the tile, which says so in red, and
	// only a second press within a few seconds goes through. Suspend loses
	// nothing, so it does not ask.
	component SessionTile: MiniTile {
		id: session

		property string name
		property bool confirm: false
		// Red from the start, for the one that turns the machine off.
		property bool risky: false
		property bool armed: false

		signal confirmed()

		label: session.armed ? "Confirm?" : session.name
		danger: session.risky || session.armed
		focused: root.cur === session

		onTriggered: {
			if (session.confirm && !session.armed) {
				session.armed = true;
				disarm.restart();
				return;
			}
			session.armed = false;
			root.dismiss();
			session.confirmed();
		}

		// An armed tile that scrolled out of sight, or whose pane was closed,
		// must not still be armed when it is next seen.
		onVisibleChanged: if (!visible) session.armed = false

		Timer {
			id: disarm

			interval: 3000
			onTriggered: session.armed = false
		}
	}

	// A square button in the header.
	component HeadButton: MouseArea {
		id: button

		property string icon
		// Lit while the pane it opens is open.
		property bool active: false
		// Keyboard cursor, set by the panel.
		property bool focused: false
		readonly property bool toggleable: false

		signal triggered()

		Layout.preferredWidth: 34
		Layout.preferredHeight: 34

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: button.triggered()

		Rectangle {
			readonly property color surface: button.active ? Config.accent : Config.bgAlt

			anchors.fill: parent
			radius: Config.radius - 2
			scale: button.pressed ? 0.94 : 1
			color: button.containsMouse ? Config.hover(surface) : surface
			border.width: button.focused ? 2 : 0
			border.color: Config.fg

			Behavior on scale {
				NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
			}
			Behavior on color {
				ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
			}
		}

		Label {
			anchors.centerIn: parent
			text: button.icon
			color: button.active ? Config.bg : Config.fg
			font.pixelSize: Config.fontSize
		}
	}
}
