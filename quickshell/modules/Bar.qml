import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.widgets

PanelWindow {
	id: bar

	required property var modelData
	screen: modelData

	// Top edge, full width. Anchoring left+right stretches the panel.
	anchors {
		top: true
		left: true
		right: true
	}

	margins {
		top: Config.barMargin
		left: Config.barMargin
		right: Config.barMargin
	}

	implicitHeight: Config.barHeight
	color: "transparent"
	// Reserve space so windows never sit under the bar. mango then adds its
	// own gappov below this zone, which is what actually forms the gap under
	// the bar — so it is subtracted here to keep the spacing even all round.
	exclusiveZone: Math.max(0, Config.barHeight + Config.barMargin * 2
		- Config.compositorGap)

	Rectangle {
		anchors.fill: parent
		color: Config.bg
		radius: Config.barMargin > 0 ? Config.radius : 0

		border.width: 1
		border.color: Config.border

		Behavior on color {
			ColorAnimation { duration: Config.themeFade }
		}

		Behavior on border.color {
			ColorAnimation { duration: Config.themeFade }
		}
	}

	Item {
		anchors.fill: parent
		anchors.leftMargin: Config.padding
		anchors.rightMargin: Config.padding

		// ---- left ----
		RowLayout {
			id: leftSection

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: Config.spacing

			WindowTitle {
				// Stop one padding short of the centered clock, so a long title
				// elides instead of running underneath it.
				Layout.maximumWidth: Math.max(0, centerSection.x - leftSection.x
					- Config.padding)
			}
		}

		// ---- center ----
		// Anchored to the bar itself, so it is unaffected by the width of
		// whatever sits to its left or right. The group is centred as a whole,
		// so adding the cog shifts the clock by a fixed amount but never
		// lets it drift with the window title.
		RowLayout {
			id: centerSection

			anchors.horizontalCenter: parent.horizontalCenter
			anchors.verticalCenter: parent.verticalCenter
			spacing: Config.spacing

			Clock {}
			Settings {}
		}

		// ---- right ----
		RowLayout {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: Config.spacing

			RecordIndicator {}
			SysTray {}
			NotificationCenter {}
			NetSpeed {}
			Resources {}
			Volume {}
			Battery {}
		}
	}
}
