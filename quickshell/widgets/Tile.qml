import QtQuick
import QtQuick.Layouts
import qs

// One tile in the control centre.
//
// The body and the switch are separate hit targets on purpose: opening a
// detail pane and cutting the radio are very different intentions, and one
// misplaced click should not turn the network off.
MouseArea {
	id: root

	property string icon
	property string label
	property string detail
	property bool on: false
	property bool toggleable: false
	property bool expanded: false
	property bool busy: false

	// Puts minus and plus either side of the status line, for a value that can
	// be nudged without giving it a slider of its own. Scrolling the tile does
	// the same. Row variant only.
	property bool stepper: false

	// Keyboard cursor, set by the panel that owns the tiles.
	property bool focused: false

	// "row"  — icon, text and control on one line (the default width unit)
	// "tall" — a double-height tile, text sitting under a large icon
	// "mini" — a single square cell: centred icon over a short label
	property string variant: "row"

	signal triggered()
	signal toggled()
	signal stepped(int dir)

	// Marks a destructive action. The tile keeps its usual dark surface and
	// turns its glyph and label red instead: among a grid of dark tiles a
	// fully filled red one reads as "currently on" rather than "careful".
	property bool danger: false

	// Filled when lit, so an enabled feature reads at a glance.
	readonly property color surface: on ? Config.accent : Config.bgAlt
	readonly property color ink: root.danger
		? Config.red
		: on ? Config.bg : Config.fg
	readonly property color inkDim: root.danger
		? Qt.alpha(Config.red, 0.75)
		: on
			? Qt.rgba(Config.bg.r, Config.bg.g, Config.bg.b, 0.7)
			: Config.fgDim

	// The icon's round backing. Accent-tinted while off so the icon, rather
	// than the whole tile, carries the colour until the tile is lit.
	readonly property color badge: root.danger ? Qt.alpha(Config.red, 0.16)
		: on ? Qt.alpha(Config.bg, 0.16) : Qt.alpha(Config.accent, 0.18)
	readonly property color badgeInk: root.danger ? Config.red
		: on ? Config.bg : Config.accent

	implicitHeight: 58

	hoverEnabled: true
	cursorShape: Qt.PointingHandCursor
	onClicked: root.triggered()
	onWheel: event => {
		if (root.stepper && event.angleDelta.y !== 0) root.stepped(event.angleDelta.y > 0 ? 1 : -1);
		else event.accepted = false;
	}

	Rectangle {
		anchors.fill: parent

		// Scaled here rather than on the tile, so a press does not re-rasterise
		// the text sitting on top.
		radius: Config.radius
		scale: root.pressed ? 0.97 : 1
		color: root.containsMouse ? Config.hover(root.surface) : root.surface

		// The open pane is tied back to the tile that owns it. A lit tile is
		// already accent, so its ring has to be something else to show at all.
		border.width: root.expanded || root.focused ? 2 : 0
		border.color: root.focused || root.on ? Config.fg : Config.accent

		Behavior on scale {
			NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
		}
		Behavior on color {
			ColorAnimation { duration: Config.themeFade; easing.type: Easing.OutCubic }
		}
		Behavior on border.color {
			ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
		}
		Behavior on border.width {
			NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
		}
	}

	// ---- row ----
	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 11
		anchors.rightMargin: 14
		spacing: 10

		visible: root.variant === "row"

		Rectangle {
			Layout.preferredWidth: 36
			Layout.preferredHeight: 36
			radius: Config.radius - 4
			color: root.badge

			Label {
				anchors.centerIn: parent
				text: root.icon
				color: root.badgeInk
				font.pixelSize: Config.fontSize + 2
			}
		}

		ColumnLayout {
			Layout.fillWidth: true
			Layout.minimumWidth: 0
			spacing: 1

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: root.label
				color: root.ink
				font.pixelSize: Config.fontSize - 1
				elide: Text.ElideRight
			}

			// The status line carries an SSID or a device name, so it has to
			// be free to shrink rather than push the switch off the tile.
			RowLayout {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				spacing: 4
				visible: root.detail !== ""

				Step {
					visible: root.stepper
					glyph: Config.icons.minus
					dir: -1
				}

				Label {
					Layout.fillWidth: !root.stepper
					Layout.minimumWidth: 0
					text: root.detail
					color: root.inkDim
					font.pixelSize: Config.fontSize - 3
					elide: Text.ElideRight
				}

				Step {
					visible: root.stepper
					glyph: Config.icons.plus
					dir: 1
				}
			}
		}

		Switch {
			Layout.alignment: Qt.AlignVCenter
			visible: root.toggleable
		}

		Label {
			Layout.alignment: Qt.AlignVCenter
			visible: !root.toggleable
			text: root.expanded ? Config.icons.chevron : Config.icons.chevronRight
			color: root.inkDim
			font.pixelSize: Config.fontSize - 4
		}
	}

	// ---- tall ----
	Item {
		anchors.fill: parent
		anchors.margins: 14
		visible: root.variant === "tall"

		Rectangle {
			anchors.top: parent.top
			anchors.left: parent.left
			width: 44
			height: 44
			radius: Config.radius - 4
			color: root.badge

			Label {
				anchors.centerIn: parent
				text: root.icon
				color: root.badgeInk
				font.pixelSize: Config.fontSize + 7
			}
		}

		Switch {
			anchors.top: parent.top
			anchors.right: parent.right
			visible: root.toggleable
		}

		// Anchored to the bottom so the label sits still while the status
		// line above it changes length.
		Column {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			spacing: 1

			Label {
				width: parent.width
				text: root.label
				color: root.ink
				font.pixelSize: Config.fontSize + 1
				elide: Text.ElideRight
			}

			Label {
				width: parent.width
				text: root.detail
				color: root.inkDim
				font.pixelSize: Config.fontSize - 3
				elide: Text.ElideRight
				visible: text !== ""
			}
		}
	}

	// ---- mini ----
	Column {
		anchors.centerIn: parent
		width: parent.width - 8
		spacing: 3
		visible: root.variant === "mini"

		Label {
			anchors.horizontalCenter: parent.horizontalCenter
			text: root.busy ? Config.icons.spinner : root.icon
			color: root.on ? root.ink : root.badgeInk
			font.pixelSize: Config.fontSize + 5

			RotationAnimation on rotation {
				running: root.busy && root.variant === "mini"
				loops: Animation.Infinite
				from: 0
				to: 360
				duration: 900
			}
		}

		Label {
			width: parent.width
			text: root.detail || root.label
			color: root.inkDim
			font.pixelSize: Config.fontSize - 3
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
		}
	}

	// Its own hit target, so a step can never fall through and flip the tile.
	component Step: MouseArea {
		id: step

		property string glyph
		property int dir

		implicitWidth: 20
		implicitHeight: 18

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.stepped(dir)

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 6
			color: step.pressed || step.containsMouse ? root.badge : "transparent"
		}

		Label {
			anchors.centerIn: parent
			text: step.glyph
			color: root.ink
			font.pixelSize: Config.fontSize - 5
		}
	}

	// A drawn switch rather than a glyph, so the knob can travel.
	component Switch: MouseArea {
		id: sw

		implicitWidth: 38
		implicitHeight: 22

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.toggled()

		Rectangle {
			anchors.fill: parent
			radius: Config.radius
			color: root.on ? Config.bg : "transparent"
			border.width: root.on ? 0 : 2
			border.color: sw.containsMouse ? Config.accent : Config.fgDim

			Behavior on color {
				ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
			}
		}

		Rectangle {
			anchors.verticalCenter: parent.verticalCenter
			visible: !root.busy
			width: root.on ? 16 : 10
			height: width
			radius: Config.radius
			x: root.on ? parent.width - width - 3 : 6
			color: root.on ? Config.accent
				: sw.containsMouse ? Config.accent : Config.fgDim

			Behavior on x {
				NumberAnimation { duration: Config.animMed; easing.type: Easing.OutBack }
			}
			Behavior on width {
				NumberAnimation { duration: Config.animMed; easing.type: Easing.OutCubic }
			}
		}

		Label {
			anchors.centerIn: parent
			visible: root.busy
			text: Config.icons.spinner
			color: root.on ? Config.accent : root.ink
			font.pixelSize: Config.fontSize - 2

			RotationAnimation on rotation {
				running: root.busy
				loops: Animation.Infinite
				from: 0
				to: 360
				duration: 900
			}
		}
	}
}
