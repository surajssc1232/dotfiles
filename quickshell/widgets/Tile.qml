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

	// "row"  — icon, text and control on one line (the default width unit)
	// "tall" — a double-height tile, text sitting under a large icon
	// "mini" — a single square cell: centred icon over a short label
	property string variant: "row"

	signal triggered()
	signal toggled()

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

	implicitHeight: 54

	hoverEnabled: true
	cursorShape: Qt.PointingHandCursor
	onClicked: root.triggered()

	Rectangle {
		anchors.fill: parent

		radius: Config.radius
		color: root.containsMouse ? Qt.lighter(root.surface, 1.25) : root.surface

		// The open pane is tied back to the tile that owns it.
		border.width: root.expanded ? 2 : 1
		border.color: root.expanded ? Config.accent : Config.border

		Behavior on color {
			ColorAnimation { duration: Config.themeFade }
		}
	}

	// ---- row ----
	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: 10
		anchors.rightMargin: 8
		spacing: 8

		visible: root.variant === "row"

		Label {
			text: root.icon
			color: root.ink
			font.pixelSize: Config.fontSize + 2
		}

		ColumnLayout {
			Layout.fillWidth: true
			Layout.minimumWidth: 0
			spacing: 0

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
			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: root.detail
				color: root.inkDim
				font.pixelSize: Config.fontSize - 4
				elide: Text.ElideRight
				visible: text !== ""
			}
		}

		MouseArea {
			id: toggle

			Layout.preferredWidth: 22
			Layout.preferredHeight: 22
			Layout.alignment: Qt.AlignVCenter

			visible: root.toggleable
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.toggled()

			Label {
				anchors.centerIn: parent
				text: root.busy ? Config.icons.spinner
					: root.on ? Config.icons.toggleOn : Config.icons.toggleOff
				color: toggle.containsMouse ? Config.blue : root.ink
				font.pixelSize: Config.fontSize + 1

				RotationAnimation on rotation {
					running: root.busy
					loops: Animation.Infinite
					from: 0
					to: 360
					duration: 900
				}
			}
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
		anchors.margins: 10
		visible: root.variant === "tall"

		Label {
			id: tallIcon
			anchors.top: parent.top
			anchors.left: parent.left
			text: root.icon
			color: root.ink
			font.pixelSize: Config.fontSize + 10
		}

		MouseArea {
			anchors.top: parent.top
			anchors.right: parent.right
			width: 24
			height: 24

			visible: root.toggleable
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: root.toggled()

			Label {
				anchors.centerIn: parent
				text: root.busy ? Config.icons.spinner
					: root.on ? Config.icons.toggleOn : Config.icons.toggleOff
				color: parent.containsMouse ? Config.blue : root.ink
				font.pixelSize: Config.fontSize + 1

				RotationAnimation on rotation {
					running: root.busy
					loops: Animation.Infinite
					from: 0
					to: 360
					duration: 900
				}
			}
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
				font.pixelSize: Config.fontSize
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
			color: root.ink
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
			font.pixelSize: Config.fontSize - 4
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
		}
	}
}
