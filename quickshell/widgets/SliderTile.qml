import QtQuick
import QtQuick.Layouts
import qs

// A wide tile that is its own control: drag the bar to set the value. These
// need no detail pane, which is the point of giving them the extra width.
Item {
	id: root

	property string icon
	property string label
	property real value: 0          // 0..1
	property string readout
	property bool dimmed: false     // muted, or otherwise inactive
	property color fill: Config.accent

	// One wheel notch.
	property real step: 0.05

	// Shows a chevron that reveals a device list under the tile.
	property bool expandable: false
	property bool expanded: false

	signal toggled()

	signal moved(real value)
	signal iconClicked()

	// Split out of the wheel handler so it can be driven directly, and so the
	// clamping lives in one place.
	//
	// The result is snapped to the step grid rather than just added to the
	// current value: the reading comes back from the device rounded, so
	// repeated relative steps drift (six notches of 5% landed on 68%, not 70).
	// Snapping makes every notch land on a round number and corrects any drift
	// that has already crept in.
	function scrollBy(dir: int) {
		if (dir === 0) return;

		// A Pipewire sink can sit above 100%, past the end of this slider.
		// Scrolling up there must do nothing rather than snap back into range,
		// or asking for "louder" would quietly make it quieter.
		if (dir > 0 && root.value >= 1) return;

		const base = Math.min(1, root.value);
		const next = Math.round((base + dir * root.step) / root.step) * root.step;
		root.moved(Math.max(0, Math.min(1, next)));
	}

	implicitHeight: 54

	Rectangle {
		anchors.fill: parent
		radius: Config.radius
		color: Config.bgAlt
		border.width: 1
		border.color: Config.border
	}

	// Scrolls anywhere on the tile, not just over the bar. Declared before the
	// content so it sits underneath: it takes no buttons, and the controls
	// above it handle no wheel, so the event falls through to here.
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.NoButton

		onWheel: event => root.scrollBy(event.angleDelta.y > 0 ? 1
			: event.angleDelta.y < 0 ? -1 : 0)
	}

	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 10
		anchors.rightMargin: 12
		spacing: 10

		// Doubles as the mute button where that makes sense.
		MouseArea {
			Layout.preferredWidth: 22
			Layout.preferredHeight: 22
			Layout.alignment: Qt.AlignVCenter

			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.iconClicked()

			Label {
				anchors.centerIn: parent
				text: root.icon
				color: root.dimmed ? Config.fgDim : root.fill
				font.pixelSize: Config.fontSize + 1
			}
		}

		ColumnLayout {
			id: body

			Layout.fillWidth: true
			Layout.minimumWidth: 0
			spacing: 5

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: root.label
					color: Config.fg
					font.pixelSize: Config.fontSize - 2
					elide: Text.ElideRight
				}

				Label {
					text: root.readout
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 3
				}
			}

			// ---- track ----
			Item {
				id: track

				Layout.fillWidth: true
				Layout.preferredHeight: 14

				function commit(x) {
					root.moved(Math.max(0, Math.min(1, x / track.width)));
				}

				Rectangle {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width
					height: 6
					radius: 3
					color: Config.bg
					border.width: 1
					border.color: Config.border

					Rectangle {
						width: Math.round(parent.width * Math.max(0, Math.min(1, root.value)))
						height: parent.height
						radius: parent.radius
						color: root.dimmed ? Config.fgDim : root.fill
					}
				}

				// Grabbed as soon as it is pressed, so a click anywhere on the
				// bar jumps there and keeps tracking without a second press.
				MouseArea {
					anchors.fill: parent
					anchors.leftMargin: -4
					anchors.rightMargin: -4
					preventStealing: true
					cursorShape: Qt.PointingHandCursor

					onPressed: event => track.commit(event.x)
					onPositionChanged: event => {
						if (pressed) track.commit(event.x);
					}
				}
			}
		}

		// Opens the device list. Its own hit target, so reaching for the
		// device menu can never nudge the volume on the way past.
		MouseArea {
			Layout.preferredWidth: 20
			Layout.preferredHeight: 22
			Layout.alignment: Qt.AlignVCenter

			visible: root.expandable
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.toggled()

			Label {
				anchors.centerIn: parent
				text: root.expanded ? Config.icons.chevron : Config.icons.chevronRight
				color: parent.containsMouse || root.expanded ? Config.accent : Config.fgDim
				font.pixelSize: Config.fontSize - 4
			}
		}
	}
}
