import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.services

// Frosted glass: the wallpaper, blurred, clipped to this item. niri has no
// background blur of its own, so a surface that sits over the wallpaper
// paints its own copy, laid out as WallpaperLayer lays it out and shifted by
// where this item is on the screen, so what shows is what is really behind.
Item {
	id: root

	// The output this sits on, and this item's top-left in its pixels.
	property var screen: Quickshell.screens[0]
	property real screenX: 0
	property real screenY: 0
	property real radius: 0

	visible: Config.glass && Wallpaper.current !== ""
	layer.enabled: visible
	layer.effect: MultiEffect {
		maskEnabled: true
		maskSource: mask
	}

	Image {
		x: -root.screenX
		y: -root.screenY
		width: root.screen?.width ?? 1920
		height: root.screen?.height ?? 1080
		source: root.visible && Wallpaper.current ? "file://" + Wallpaper.current : ""
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		sourceSize.width: 960
		layer.enabled: true
		layer.effect: MultiEffect {
			blurEnabled: true
			blur: 1.0
			blurMax: 48
			saturation: 0.2
		}
	}

	Rectangle {
		id: mask

		anchors.fill: parent
		radius: root.radius
		visible: false
		layer.enabled: true
	}
}
