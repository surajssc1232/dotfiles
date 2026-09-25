import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

// Toast stack under the right end of the bar.
PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	visible: Notifs.popups.length > 0

	anchors {
		top: true
		right: true
	}

	margins {
		top: Config.barMargin * 2 + Config.barHeight
		right: Config.barMargin
	}

	implicitWidth: 380
	implicitHeight: Math.max(1, column.implicitHeight)

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay

	// Only the cards take clicks; the gaps between them stay click-through
	// so the toast stack never swallows input meant for the window below.
	mask: Region {
		item: column
	}

	ColumnLayout {
		id: column

		width: parent.width
		spacing: Config.spacing

		Repeater {
			model: Notifs.popups

			NotificationCard {
				id: card

				required property var modelData

				Layout.fillWidth: true

				notif: modelData
				onClosed: Notifs.dismiss(modelData)

				// Hovering holds the toast open, so it cannot vanish out from
				// under the pointer on the way to a button.
				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.NoButton
					hoverEnabled: true
					z: -1
					onEntered: life.stop()
					onExited: if (life.interval > 0) life.restart()
				}

				Timer {
					id: life

					interval: Notifs.timeoutFor(card.modelData)
					running: interval > 0
					onTriggered: Notifs.hidePopup(card.modelData)
				}

				// Fades in where it belongs rather than flying in from the
				// edge, but visibly: a toast that only lives two seconds has
				// to announce itself in the first third of that.
				readonly property bool leaving:
					Notifs.leaving.indexOf(card.modelData) !== -1

				// Off until the card has decided whether it is arriving or
				// merely being rebuilt, so a rebuild can jump straight to its
				// final state without animating.
				property bool animated: false

				opacity: 0
				scale: 0.85
				transformOrigin: Item.Right

				Behavior on opacity {
					enabled: card.animated
					NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
				}

				Behavior on scale {
					enabled: card.animated
					NumberAnimation { duration: 320; easing.type: Easing.OutBack }
				}

				Component.onCompleted: {
					const fresh = !Notifs.hasArrived(card.modelData);

					if (card.leaving) {
						// Rebuilt mid-exit: already on its way out.
						card.opacity = 0;
						card.scale = 0.9;
						card.animated = true;
						return;
					}

					if (!fresh) {
						// A rebuild, not an arrival. Snap to where it was.
						card.opacity = 1;
						card.scale = 1;
						card.animated = true;
						return;
					}

					Notifs.markArrived(card.modelData);
					card.animated = true;
					// Next tick, so the animation has a starting point to
					// move away from rather than being set in the same frame.
					Qt.callLater(() => {
						card.opacity = 1;
						card.scale = 1;
					});
				}

				onLeavingChanged: if (card.leaving) {
					card.opacity = 0;
					card.scale = 0.9;
				}
			}
		}
	}
}
