import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.widgets

// Battery level; click for time remaining and the CPU power profile.
Pill {
	id: root

	readonly property var battery: UPower.displayDevice
	readonly property int percent: battery ? Math.round(battery.percentage * 100) : 0
	readonly property bool charging: battery?.state === UPowerDeviceState.Charging
		|| battery?.state === UPowerDeviceState.FullyCharged

	readonly property int menuWidth: 240
	readonly property int rowHeight: 30

	// Hidden on desktops, where there is no battery to report.
	visible: battery?.isLaptopBattery ?? false

	interactive: true
	onClicked: layer.open = !layer.open

	// Seconds to a human phrase; UPower reports 0 when it has no estimate yet.
	function remaining(): string {
		if (!root.battery) return "";
		const secs = root.charging ? root.battery.timeToFull : root.battery.timeToEmpty;
		if (!secs || secs <= 0)
			return root.battery.state === UPowerDeviceState.FullyCharged ? "Full" : "Estimating…";

		const hours = Math.floor(secs / 3600);
		const mins = Math.round((secs % 3600) / 60);
		const time = hours > 0 ? hours + "h " + mins + "m" : mins + "m";
		return time + (root.charging ? " to full" : " left");
	}

	Label {
		text: root.charging
			? Config.icons.charging
			: Config.icons.battery[Math.min(4, Math.floor(root.percent / 20))]
		color: root.charging ? Config.green
			: root.percent <= 15 ? Config.red
			: root.percent <= 30 ? Config.yellow
			: Config.fg
	}

	Label {
		text: root.percent + "%"
	}

	// Only worth the space when it is not the default.
	Label {
		text: Power.icon(Power.profile)
		color: Power.profile === "performance" ? Config.red
			: Power.profile === "power-saver" ? Config.green
			: Config.fgDim
		font.pixelSize: Config.fontSize - 3
		visible: Power.available && Power.profile !== "balanced"
	}

	PopupLayer {
		id: layer

		anchorItem: root
		contentWidth: root.menuWidth
		contentHeight: body.implicitHeight + Config.padding

		onOpenChanged: {
			Power.active = open;
			if (open) Power.refresh();
		}

		Panel {
			anchors.fill: parent

			ColumnLayout {
				id: body

				anchors.fill: parent
				anchors.margins: Config.padding / 2
				spacing: 2

				// ---- status ----
				RowLayout {
					Layout.fillWidth: true
					Layout.leftMargin: 8
					Layout.rightMargin: 8
					Layout.topMargin: 4
					spacing: 8

					Label {
						text: root.percent + "%"
						color: Config.accent
						font.pixelSize: Config.fontSize + 4
					}

					ColumnLayout {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						spacing: 0

						Label {
							Layout.fillWidth: true
							Layout.minimumWidth: 0
							text: root.charging ? "Charging" : "On battery"
							font.pixelSize: Config.fontSize - 2
							elide: Text.ElideRight
						}

						Label {
							Layout.fillWidth: true
							Layout.minimumWidth: 0
							text: root.remaining()
							color: Config.fgDim
							font.pixelSize: Config.fontSize - 3
							elide: Text.ElideRight
						}
					}
				}

				// Worth showing: a worn battery explains a short runtime.
				Label {
					Layout.fillWidth: true
					Layout.leftMargin: 8
					visible: root.battery?.healthSupported ?? false
					text: "Health " + Math.round((root.battery?.healthPercentage ?? 0)) + "%"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
				}

				Rectangle {
					Layout.fillWidth: true
					Layout.topMargin: 4
					Layout.bottomMargin: 2
					Layout.preferredHeight: 1
					visible: Power.available
					color: Config.border
				}

				// ---- power profile ----
				Label {
					Layout.fillWidth: true
					Layout.leftMargin: 8
					visible: Power.available
					text: "Power profile"
					color: Config.accent
					font.pixelSize: Config.fontSize - 2
				}

				Repeater {
					model: Power.available ? Power.profiles : []

					MouseArea {
						id: entry

						required property var modelData
						readonly property bool current: modelData === Power.profile

						Layout.fillWidth: true
						Layout.preferredHeight: root.rowHeight

						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: Power.set(entry.modelData)

						Rectangle {
							anchors.fill: parent
							radius: Config.radius - 4
							color: entry.containsMouse ? Config.bgAlt : "transparent"
							border.width: entry.current ? 1 : 0
							border.color: Config.accent
						}

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 8
							anchors.rightMargin: 8
							spacing: 8

							Label {
								text: Power.icon(entry.modelData)
								color: entry.current ? Config.accent : Config.fgDim
								font.pixelSize: Config.fontSize - 1
							}

							Label {
								Layout.fillWidth: true
								Layout.minimumWidth: 0
								text: Power.title(entry.modelData)
								elide: Text.ElideRight
								color: entry.current ? Config.accent : Config.fg
								font.pixelSize: Config.fontSize - 1
							}

							Label {
								text: Config.icons.check
								color: Config.accent
								visible: entry.current
								font.pixelSize: Config.fontSize - 3
							}
						}
					}
				}

				Label {
					Layout.fillWidth: true
					Layout.leftMargin: 8
					Layout.rightMargin: 8
					visible: Power.degraded !== ""
					text: "Degraded: " + Power.degraded
					color: Config.yellow
					font.pixelSize: Config.fontSize - 4
					wrapMode: Text.WordWrap
				}
			}
		}
	}
}
