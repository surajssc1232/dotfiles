import QtQuick
import Quickshell.Wayland
import qs
import qs.widgets

// Title of the currently focused window (wlr-foreign-toplevel).
Label {
	readonly property var toplevel: ToplevelManager.activeToplevel

	text: toplevel ? (toplevel.title || toplevel.appId || "") : "Desktop"
	color: toplevel ? Config.fg : Config.fgDim
	elide: Text.ElideRight
}
