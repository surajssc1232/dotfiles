import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

// NixOS status: a snowflake on the bar that turns yellow while the config has
// unapplied edits. Click for generations, input ages, store size and buttons
// to rebuild, update or collect garbage.
Pill {
	id: root

	interactive: true
	onClicked: {
		layer.open = !layer.open;
		if (layer.open) {
			NixStatus.refresh();
			NixStatus.measureStore();
		}
	}

	component Row2: RowLayout {
		id: kv
		property string key
		property string value
		property color valueColor: Config.fg
		Layout.fillWidth: true
		Layout.leftMargin: 6
		Layout.rightMargin: 6
		Label { text: kv.key; color: Config.fgDim }
		Item { Layout.fillWidth: true }
		Label { text: kv.value; color: kv.valueColor; font.bold: true }
	}

	component Action: Pill {
		id: action
		property string icon
		property string text
		signal activated()
		Layout.fillWidth: true
		interactive: true
		onClicked: action.activated()
		Label { text: action.icon; color: Config.accent }
		Label { text: action.text }
	}

	Label {
		text: Config.icons.distro["nixos"]
		color: NixStatus.pending ? Config.yellow : Config.accent
	}
	Label {
		text: "#" + NixStatus.generation
		color: Config.fgDim
		font.pixelSize: Config.fontSize - 1
	}

	PopupLayer {
		id: layer

		anchorItem: root
		contentWidth: 300
		contentHeight: body.implicitHeight + Config.inset * 2

		Panel {
			anchors.fill: parent

			ColumnLayout {
				id: body

				anchors.fill: parent
				anchors.margins: Config.inset
				spacing: 8

				Group {
					title: "System"

					Row2 { key: "Generation"; value: "#" + NixStatus.generation + "  (" + NixStatus.generations + " kept)" }
					Row2 { key: "Last rebuild"; value: NixStatus.ago(Date.now() / 1000 - NixStatus.builtAt) + " ago" }
					Row2 {
						key: "Config"
						value: NixStatus.pending ? "edited, not applied" : "applied"
						valueColor: NixStatus.pending ? Config.yellow : Config.green
					}
					Row2 {
						key: "Store size"
						value: NixStatus.measuring ? "measuring…"
							: NixStatus.storeBytes < 0 ? "—"
							: (NixStatus.storeBytes / 1073741824).toFixed(1) + " GB"
					}
				}

				Group {
					title: "Flake inputs"

					Repeater {
						model: NixStatus.inputs

						RowLayout {
							required property var modelData
							Layout.fillWidth: true
							Layout.leftMargin: 6
							Layout.rightMargin: 6
							Label { text: modelData.name; color: Config.fgDim }
							Item { Layout.fillWidth: true }
							Label {
								text: NixStatus.ago(modelData.age) + " old"
								font.bold: true
								// Over a month behind reads as stale.
								color: modelData.age > 30 * 86400 ? Config.red
									: modelData.age > 7 * 86400 ? Config.yellow : Config.green
							}
						}
					}
				}

				RowLayout {
					Layout.fillWidth: true
					spacing: 6

					Action { icon: Config.icons.refresh; text: "Rebuild"; onActivated: { layer.open = false; NixStatus.rebuild(); } }
					Action { icon: Config.icons.down; text: "Update"; onActivated: { layer.open = false; NixStatus.update(); } }
					Action { icon: Config.icons.broom; text: "GC"; onActivated: { layer.open = false; NixStatus.collectGarbage(); } }
				}
			}
		}
	}
}
