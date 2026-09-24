import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// The desktop wallpaper, painted by the shell itself.
//
// A layer-shell surface on the background layer sits under every window, which
// is all swaybg was ever doing — so there is no external process to spawn,
// track down by name, or kill when the picture changes. Changing wallpaper is
// now just changing a property.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	readonly property string source: Wallpaper.current
		? "file://" + Wallpaper.current
		: ""

	// Which of the two images is the one currently on show.
	property bool frontIsA: true

	readonly property int pixelWidth: Math.round((screen?.width ?? 1920)
		* (screen?.devicePixelRatio ?? 1))
	readonly property int pixelHeight: Math.round((screen?.height ?? 1080)
		* (screen?.devicePixelRatio ?? 1))

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}

	exclusionMode: ExclusionMode.Ignore
	focusable: false
	WlrLayershell.layer: WlrLayer.Background
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	// Shows through until an image is loaded, and wherever one does not cover
	// the screen exactly.
	color: Config.bg

	// Two images rather than one, so a change fades between them. Swapping the
	// source of a single image blanks it while the new file is decoded, which
	// on a multi-megabyte photograph is a visible flash of empty desktop.
	onSourceChanged: {
		const incoming = root.frontIsA ? imageB : imageA;
		if (incoming.source === root.source) return;
		incoming.source = root.source;
	}

	Image {
		id: imageA

		anchors.fill: parent
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		// Decoded at the screen's real pixel count — logical size times the
		// scale factor, which is 2 here, so decoding at logical size would
		// halve the resolution and show. Beyond that there is nothing to gain
		// from keeping more pixels than are displayed.
		sourceSize.width: root.pixelWidth
		sourceSize.height: root.pixelHeight
		// Only one wallpaper is ever on screen, so caching decoded copies of
		// every one that has been previewed would waste a lot of memory.
		cache: false

		opacity: root.frontIsA ? 1 : 0
		Behavior on opacity { NumberAnimation { duration: 220 } }

		onStatusChanged: if (status === Image.Ready && !root.frontIsA) root.frontIsA = true
	}

	Image {
		id: imageB

		anchors.fill: parent
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		sourceSize.width: root.screen?.width ?? 1920
		sourceSize.height: root.screen?.height ?? 1080
		cache: false

		opacity: root.frontIsA ? 0 : 1
		Behavior on opacity { NumberAnimation { duration: 220 } }

		onStatusChanged: if (status === Image.Ready && root.frontIsA) root.frontIsA = false
	}

	Component.onCompleted: {
		imageA.source = root.source;
		root.frontIsA = true;
	}
}
