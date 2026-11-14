import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Floating scratchpad, top-right under the bar. Mod+Shift+N or Escape closes it.
// Only shown on the focused screen, so two copies never compete for typing.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property bool here: Quickshell.screens.length < 2
		|| (Niri.workspaces.find(w => w.is_focused)?.output ?? modelData.name) === modelData.name

	visible: Notes.shown && root.here || card.opacity > 0

	anchors {
		top: true
		right: true
	}

	margins {
		top: Config.barMargin * 2 + Config.barHeight + 4
		right: Config.barMargin + 4
	}

	implicitWidth: 380
	implicitHeight: 420
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-notes"
	WlrLayershell.keyboardFocus: Notes.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	Panel {
		id: card

		anchors.fill: parent
		opacity: Notes.shown ? 1 : 0
		scale: Notes.shown ? 1 : 0.96
		transformOrigin: Item.TopRight

		Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
		Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Config.inset
			spacing: 8

			RowLayout {
				Layout.fillWidth: true

				Label { text: Config.icons.pin; color: Config.accent }
				Label { text: "Notes"; font.bold: true }
				Item { Layout.fillWidth: true }
				Label {
					text: editor.text.length + " chars"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
				}
			}

			Rectangle {
				Layout.fillWidth: true
				Layout.fillHeight: true
				radius: Config.radius - 2
				color: Config.surfaceGroup

				Flickable {
					id: flick

					anchors.fill: parent
					anchors.margins: 10
					clip: true
					contentWidth: width
					contentHeight: editor.implicitHeight
					boundsBehavior: Flickable.StopAtBounds

					// Keeps the cursor in view while typing past the bottom.
					function follow(r) {
						if (r.y < contentY) contentY = r.y;
						else if (r.y + r.height > contentY + height)
							contentY = r.y + r.height - height;
					}

					TextEdit {
						id: editor

						width: flick.width
						wrapMode: TextEdit.Wrap
						color: Config.fg
						selectionColor: Qt.alpha(Config.accent, 0.4)
						selectedTextColor: Config.fg
						font.family: Config.font
						font.pixelSize: Config.fontSize
						selectByMouse: true
						focus: true

						text: Notes.text
						onTextChanged: if (text !== Notes.text) Notes.edit(text)
						onCursorRectangleChanged: flick.follow(cursorRectangle)

						Keys.onEscapePressed: Notes.shown = false

						Label {
							visible: editor.text.length === 0
							text: "Jot something down…"
							color: Config.fgDim
						}
					}
				}
			}
		}
	}

	onVisibleChanged: if (visible) editor.forceActiveFocus()
}
