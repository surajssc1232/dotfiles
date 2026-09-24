import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Full-screen capture surface, one per monitor.
//
// The frame is taken while this window is still fully transparent, so the
// overlay contributes nothing to the composite and cannot photograph itself.
// Everything drawn afterwards — the dimming, the selection box — sits beside
// the captured frame rather than inside it, so none of it reaches the file.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	// Frozen frame is ready and the selection UI is live.
	property bool ready: false
	property bool dragging: false
	property real originX: 0
	property real originY: 0
	property rect selection: Qt.rect(0, 0, 0, 0)

	visible: Shot.capturing

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

	onVisibleChanged: if (!visible) {
		root.ready = false;
		root.dragging = false;
		root.selection = Qt.rect(0, 0, 0, 0);
		cropper.x = 0;
		cropper.y = 0;
		cropper.width = root.width;
		cropper.height = root.height;
	}

	function finish(area: rect) {
		if (area.width < 1 || area.height < 1) {
			Shot.cancel();
			return;
		}

		// Move the frame into the crop window, then let one frame render
		// before grabbing: grabToImage reads what has actually been drawn.
		cropper.x = area.x;
		cropper.y = area.y;
		cropper.width = area.width;
		cropper.height = area.height;
		root.ready = false;          // hide the chrome so nothing bleeds in
		grabDelay.restart();
	}

	Timer {
		id: grabDelay
		interval: 32
		onTriggered: {
			const path = Shot.nextPath();
			cropper.grabToImage(result => Shot.afterSave(path, result.saveToFile(path)),
				Qt.size(cropper.width, cropper.height));
		}
	}

	// ---- the captured frame, and the crop window over it ----
	Item {
		id: cropper

		x: 0
		y: 0
		width: root.width
		height: root.height
		clip: true

		ScreencopyView {
			id: capture

			// Bound to the capture state rather than set once: the view starts
			// grabbing the moment it has a source, and a source set at
			// construction meant the frame arrived before anyone asked for it,
			// leaving hasContent already true and its change signal spent.
			captureSource: Shot.capturing ? root.screen : null
			live: false
			paintCursor: false

			// Stays pinned to the output regardless of where the crop window
			// moves, so the visible pixels are always the right ones.
			x: -cropper.x
			y: -cropper.y
			width: root.width
			height: root.height

			onHasContentChanged: if (hasContent && Shot.capturing) {
				// The frame is captured; whatever posed for it may now leave.
				Shot.frameReady = true;
				if (Shot.mode === "full") root.finish(Qt.rect(0, 0, root.width, root.height));
				else root.ready = true;
			}
		}
	}

	// ---- dimming, everywhere except the selection ----
	// Four panes rather than one with a hole, so the selected region is shown
	// at its true brightness.
	Item {
		anchors.fill: parent
		visible: root.ready

		Repeater {
			model: 4

			Rectangle {
				required property int index

				readonly property rect sel: root.selection
				readonly property bool empty: sel.width < 1 || sel.height < 1

				color: "#000000"
				opacity: 0.45

				// Panes 0 and 2 are full-width bands above and below the
				// selection, so they start at the screen edge; only the side
				// panes are inset to the selection.
				x: empty || index === 0 || index === 1 || index === 2
					? 0
					: sel.x + sel.width
				y: empty ? 0 : (index === 0 ? 0 : index === 2 ? sel.y + sel.height : sel.y)
				width: empty ? (index === 0 ? root.width : 0)
					: (index === 0 || index === 2) ? root.width
					: index === 1 ? sel.x : root.width - sel.x - sel.width
				height: empty ? (index === 0 ? root.height : 0)
					: index === 0 ? sel.y
					: index === 2 ? root.height - sel.y - sel.height
					: sel.height
			}
		}
	}

	// ---- selection box ----
	Rectangle {
		visible: root.ready && root.selection.width > 0 && root.selection.height > 0

		x: root.selection.x
		y: root.selection.y
		width: root.selection.width
		height: root.selection.height

		color: "transparent"
		border.width: 1
		border.color: Config.accent

		Rectangle {
			anchors.bottom: parent.top
			anchors.bottomMargin: 4
			anchors.horizontalCenter: parent.horizontalCenter

			width: size.implicitWidth + 12
			height: size.implicitHeight + 6
			radius: Config.radius - 4
			color: Config.bg
			border.width: 1
			border.color: Config.border
			visible: parent.width > 60

			Label {
				id: size
				anchors.centerIn: parent
				text: Math.round(root.selection.width) + " × " + Math.round(root.selection.height)
				color: Config.accent
				font.pixelSize: Config.fontSize - 2
			}
		}
	}

	// ---- hint ----
	Rectangle {
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		anchors.topMargin: Config.barMargin * 2 + Config.barHeight

		width: hint.implicitWidth + 24
		height: hint.implicitHeight + 14
		radius: Config.radius
		color: Config.bg
		border.width: 1
		border.color: Config.border
		visible: root.ready && !root.dragging && root.selection.width < 1

		Label {
			id: hint
			anchors.centerIn: parent
			text: "Drag to select  ·  Enter for the whole screen  ·  Esc to cancel"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 2
		}
	}

	// ---- input ----
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		cursorShape: Qt.CrossCursor

		onPressed: event => {
			// Right click always escapes, even before the frame lands.
			if (event.button === Qt.RightButton) {
				Shot.cancel();
				return;
			}
			if (!root.ready) return;
			root.originX = event.x;
			root.originY = event.y;
			root.dragging = true;
			root.selection = Qt.rect(event.x, event.y, 0, 0);
		}

		onPositionChanged: event => {
			if (!root.dragging) return;
			// Normalised, so dragging up or left works the same as down-right.
			root.selection = Qt.rect(Math.min(root.originX, event.x),
				Math.min(root.originY, event.y),
				Math.abs(event.x - root.originX),
				Math.abs(event.y - root.originY));
		}

		onReleased: {
			if (!root.dragging) return;
			root.dragging = false;
			// A stray click is a cancel, not a one-pixel screenshot.
			if (root.selection.width < 4 || root.selection.height < 4) {
				root.selection = Qt.rect(0, 0, 0, 0);
				return;
			}
			root.finish(root.selection);
		}
	}

	Item {
		anchors.fill: parent
		// Focused whenever the overlay is up, not only once it is ready: this
		// window takes the keyboard exclusively, so Esc has to work even if
		// the capture never arrives.
		focus: true

		Keys.onEscapePressed: Shot.cancel()
		Keys.onReturnPressed: root.finish(Qt.rect(0, 0, root.width, root.height))
		Keys.onEnterPressed: root.finish(Qt.rect(0, 0, root.width, root.height))
	}
}
