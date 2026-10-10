import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// A full-screen transparent layer that hosts one bar popup.
//
// PopupWindow (an xdg popup) has no dismiss handling on wlroots compositors,
// and a separate click-catcher surface would stack unpredictably against it.
// Drawing the menu into one overlay surface instead makes "click anywhere
// else to close" fall out for free, and lets the content resize freely —
// which an already-mapped popup window cannot do.
PanelWindow {
	id: root

	// Bar item the content is centred under.
	property Item anchorItem
	property int contentWidth: 0
	property int contentHeight: 0
	property bool open: false

	// Layer-shell surfaces get no keyboard unless they ask for it. Menus that
	// contain a text field turn this on for as long as the field is up.
	property bool keyboardFocus: false

	default property alias content: container.data

	visible: open
	screen: anchorItem?.QsWindow?.window?.screen ?? null

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}

	// Ignore, and *without* also setting exclusiveZone: assigning that
	// property flips the mode back to Normal, which lets the bar's own
	// reserved strip shrink this layer and drop the menu ~40px too low.
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	focusable: keyboardFocus
	WlrLayershell.layer: WlrLayer.Overlay

	// Sits below the content, so anything not on a menu closes it.
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		onPressed: root.open = false
	}

	Item {
		id: container

		width: root.contentWidth
		height: root.contentHeight

		// Just below the floating bar.
		y: Config.barMargin * 2 + Config.barHeight

		// Centred under the anchor, then pulled back inside the screen if a
		// wide menu near an edge would otherwise hang off it. Computed once per
		// open: bar items resize as their content changes (a new notification
		// bumps the bell's count), and a menu that follows would slide around
		// under the cursor.
		property int anchoredX: Config.barMargin

		function place(): void {
			if (!root.anchorItem) {
				anchoredX = Config.barMargin;
				return;
			}
			const p = root.anchorItem.mapToItem(null, 0, 0);
			const centred = Config.barMargin + p.x + (root.anchorItem.width - width) / 2;
			anchoredX = Math.round(Math.max(Config.barMargin,
				Math.min(centred, root.width - width - Config.barMargin)));
		}

		x: anchoredX
	}
	// The layer is not sized yet at the moment it opens, so place again once it is.
	onOpenChanged: if (open) container.place()
	onWidthChanged: if (open) container.place()
}
