import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

// Alt-Tab overlay.
//
// While this is up it holds the keyboard exclusively, which on wlroots means
// the compositor stops processing its own keybinds and hands every key here —
// so Tab, Shift-Tab, Escape and the Alt release are all handled locally, with
// no round trip through the compositor for each step.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	// The overlay opens under wherever the mouse is resting, so hover only
	// steers the selection once the pointer has actually moved.
	property bool hoverArmed: false

	readonly property int cardWidth: 132
	readonly property int cardHeight: 116

	visible: Windows.open

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}

	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	focusable: true
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

	onVisibleChanged: root.hoverArmed = false

	Timer {
		interval: 250
		running: Windows.open
		onTriggered: root.hoverArmed = true
	}

	// Nothing but letting go of Alt ends the switcher. This is only here so a
	// surface holding the keyboard can never be stranded on screen, and it is
	// set well past any believable pause — every key restarts it.
	Timer {
		id: idle
		interval: 5000
		running: Windows.open
		onTriggered: if (Windows.open) Windows.commit()
	}

	// Dimmed backdrop; clicking it anywhere cancels.
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		onPressed: Windows.cancel()

		Rectangle {
			anchors.fill: parent
			color: "#000000"
			opacity: 0.35
		}
	}

	Panel {
		id: card

		anchors.centerIn: parent

		// Grows with the window count, but never past the screen.
		implicitWidth: Math.min(root.width - Config.padding * 4,
			list.contentWidth + Config.padding * 2)
		implicitHeight: root.cardHeight + Config.padding * 2 + label.implicitHeight + 8

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Config.padding
			spacing: 8

			ListView {
				id: list

				Layout.fillWidth: true
				Layout.preferredHeight: root.cardHeight

				orientation: ListView.Horizontal
				model: Windows.windows
				spacing: 6
				clip: true
				boundsBehavior: Flickable.StopAtBounds
				currentIndex: Windows.index
				highlightMoveDuration: 120
				// Keeps the selection on screen when there are more windows
				// than fit across the panel.
				highlightRangeMode: ListView.ApplyRange
				preferredHighlightBegin: root.cardWidth
				preferredHighlightEnd: width - root.cardWidth

				delegate: MouseArea {
					id: entry

					required property var modelData
					required property int index
					readonly property bool current: index === Windows.index
					// Resolved once: iconPath walks the icon theme on the
					// calling thread, and this was being asked twice per card
					// on every repaint.
					readonly property string iconPath:
						Quickshell.iconPath(modelData.appId, true)

					width: root.cardWidth
					height: root.cardHeight

					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor

					// Movement, not mere presence: a pointer sitting still
					// generates no motion events, so it cannot select.
					onPositionChanged: {
						if (root.hoverArmed) Windows.index = entry.index;
					}

					onClicked: {
						Windows.index = entry.index;
						Windows.commit();
					}

					Rectangle {
						anchors.fill: parent
						radius: Config.radius - 2
						color: entry.current ? Config.bgAlt : "transparent"
						border.width: entry.current ? 2 : 1
						border.color: entry.current ? Config.accent : Config.border
					}

					ColumnLayout {
						anchors.fill: parent
						anchors.margins: 10
						spacing: 6

						IconImage {
							Layout.alignment: Qt.AlignHCenter
							Layout.preferredWidth: 48
							Layout.preferredHeight: 48

							source: entry.iconPath
							visible: entry.iconPath !== ""
						}

						// Not every app ships a matching desktop icon; fall
						// back to its initial rather than an empty gap.
						Rectangle {
							Layout.alignment: Qt.AlignHCenter
							Layout.preferredWidth: 48
							Layout.preferredHeight: 48

							radius: Config.radius - 2
							color: Config.bgAlt
							visible: entry.iconPath === ""

							Label {
								anchors.centerIn: parent
								text: (entry.modelData.appId || "?").charAt(0).toUpperCase()
								color: Config.accent
								font.pixelSize: Config.fontSize + 6
							}
						}

						Label {
							Layout.fillWidth: true
							Layout.minimumWidth: 0
							text: entry.modelData.appId || "window"
							color: entry.current ? Config.accent : Config.fgDim
							font.pixelSize: Config.fontSize - 3
							horizontalAlignment: Text.AlignHCenter
							elide: Text.ElideRight
						}
					}
				}
			}

			// The full title of the selection, which is too long for a card.
			Label {
				id: label

				Layout.fillWidth: true
				Layout.minimumWidth: 0
				text: Windows.title(Windows.selected)
				horizontalAlignment: Text.AlignHCenter
				elide: Text.ElideRight
				font.pixelSize: Config.fontSize - 1
			}
		}
	}

	// ---- keyboard ----
	Item {
		anchors.fill: parent
		focus: true

		Keys.onPressed: event => {
			idle.restart();

			if (event.key === Qt.Key_Alt) {
				event.accepted = true;
				return;
			}

			switch (event.key) {
			case Qt.Key_Tab:
			case Qt.Key_Right:
			case Qt.Key_Down:
				Windows.step(event.modifiers & Qt.ShiftModifier ? -1 : 1);
				break;
			case Qt.Key_Backtab:
			case Qt.Key_Left:
			case Qt.Key_Up:
				Windows.step(-1);
				break;
			case Qt.Key_Escape:
				Windows.cancel();
				break;
			case Qt.Key_Return:
			case Qt.Key_Enter:
			case Qt.Key_Space:
				Windows.commit();
				break;
			default:
				return;
			}
			event.accepted = true;
		}

		// Letting go of Alt is the only thing that switches the window.
		Keys.onReleased: event => {
			if (event.key === Qt.Key_Alt) {
				event.accepted = true;
				Windows.commit();
				return;
			}
			idle.restart();
		}
	}
}
