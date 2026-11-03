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

	// Keyboard cursor, set by the panel that owns the tiles.
	property bool focused: false

	// One wheel notch.
	property real step: 0.05

	// How far scrolling may go. The bar still spans 0..1 and stays full above
	// that, so dragging it can never ask for more than 100%.
	property real scrollMax: 1

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

		// A Pipewire sink can sit above scrollMax, past the end of this slider.
		// Scrolling up there must do nothing rather than snap back into range,
		// or asking for "louder" would quietly make it quieter.
		if (dir > 0 && root.value >= root.scrollMax) return;

		const base = Math.min(root.scrollMax, root.value);
		const next = Math.round((base + dir * root.step) / root.step) * root.step;
		root.moved(Math.max(0, Math.min(root.scrollMax, next)));
	}

	implicitHeight: 46

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
		spacing: 6

		// ---- track ----
		// The whole pill is the slider. The icon sits in a badge the fill
		// never shrinks past, so zero still reads as a slider and not as an
		// empty box with some text in it.
		Item {
			id: track

			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.minimumWidth: 0

			readonly property color tone: root.dimmed ? Config.fgDim : root.fill

			// Measured across the span the fill's edge actually travels, so
			// the edge lands under the pointer rather than a badge-width off.
			function commit(x) {
				const span = track.width - track.height;
				if (span > 0)
					root.moved(Math.max(0, Math.min(1, (x - track.height / 2) / span)));
			}

			Rectangle {
				anchors.fill: parent
				radius: Config.radius
				color: Config.bgAlt
				border.width: root.focused ? 2 : 0
				border.color: Config.fg
			}

			Rectangle {
				height: parent.height
				width: Math.round(parent.height
					+ (parent.width - parent.height) * Math.max(0, Math.min(1, root.value)))
				radius: Config.radius
				color: Qt.alpha(track.tone, 0.34)
			}

			// Grabbed as soon as it is pressed, so a click anywhere on the
			// bar jumps there and keeps tracking without a second press.
			MouseArea {
				anchors.fill: parent
				preventStealing: true
				cursorShape: Qt.PointingHandCursor

				onPressed: event => track.commit(event.x)
				onPositionChanged: event => {
					if (pressed) track.commit(event.x);
				}
			}

			// Doubles as the mute button where that makes sense.
			MouseArea {
				id: iconHit

				width: parent.height
				height: parent.height

				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.iconClicked()

				Rectangle {
					anchors.fill: parent
					anchors.margins: 5
					radius: Config.radius - 4
					color: iconHit.containsMouse ? Qt.tint(track.tone, Qt.alpha(Config.fg, 0.2)) : track.tone

					Label {
						anchors.centerIn: parent
						text: root.icon
						color: Config.bg
						font.pixelSize: Config.fontSize
					}
				}
			}

			RowLayout {
				anchors.fill: parent
				anchors.leftMargin: track.height + 2
				anchors.rightMargin: 16
				spacing: 8

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: root.label
					color: Config.fg
					font.pixelSize: Config.fontSize - 1
					elide: Text.ElideRight
				}

				Label {
					text: root.readout
					color: Config.fg
					opacity: 0.8
					font.pixelSize: Config.fontSize - 2
				}
			}
		}

		// Opens the device list. Its own hit target, so reaching for the
		// device menu can never nudge the volume on the way past.
		MouseArea {
			id: more

			Layout.preferredWidth: root.height
			Layout.fillHeight: true

			visible: root.expandable
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.toggled()

			Rectangle {
				anchors.fill: parent
				radius: Config.radius
				color: root.expanded ? Qt.alpha(Config.accent, 0.28)
					: more.containsMouse ? Config.hover(Config.bgAlt)
					: Config.bgAlt
			}

			Label {
				anchors.centerIn: parent
				text: root.expanded ? Config.icons.chevron : Config.icons.chevronRight
				color: more.containsMouse || root.expanded ? Config.accent : Config.fgDim
				font.pixelSize: Config.fontSize - 4
			}
		}
	}
}
