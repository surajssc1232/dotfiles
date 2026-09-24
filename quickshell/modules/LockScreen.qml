import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs
import qs.services
import qs.widgets

// The lock screen.
//
// One surface per output, created by the compositor rather than by us: a
// session lock owns every screen at once, so a monitor plugged in while locked
// comes up locked too instead of appearing as an unguarded desktop.
WlSessionLock {
	id: lock

	locked: Lock.locked

	surface: WlSessionLockSurface {
		id: surface

		// Shows through for the moment before the picture decodes, and stays
		// as the backdrop if there is no wallpaper to show at all.
		color: Config.bg

		readonly property bool prompting: Lock.prompting

		readonly property string picture: Wallpaper.lockEffective
			? "file://" + Wallpaper.lockEffective
			: ""

		SystemClock {
			id: clock
			precision: SystemClock.Seconds
		}

		// ---- backdrop ----
		// Hidden, and used only as the effect's texture. MultiEffect draws the
		// picture itself; leaving this one visible would put an unblurred copy
		// underneath the blurred one.
		Image {
			id: backdrop

			anchors.fill: parent
			visible: false

			source: surface.picture
			fillMode: Image.PreserveAspectCrop
			asynchronous: true
			cache: false
			sourceSize.width: Math.round(surface.width
				* (surface.screen?.devicePixelRatio ?? 1))
			sourceSize.height: Math.round(surface.height
				* (surface.screen?.devicePixelRatio ?? 1))
		}

		MultiEffect {
			anchors.fill: parent

			source: backdrop
			visible: backdrop.status === Image.Ready

			// The blur is the whole point of the two states, so it animates
			// rather than snapping: focus moves to the password field as the
			// desktop behind it goes soft.
			blurEnabled: true
			blurMax: 48
			blur: surface.prompting ? 1 : 0
			// Darkened a little even when idle, so white text stays readable
			// over a bright photograph, and further while typing.
			brightness: surface.prompting ? -0.34 : -0.16
			saturation: surface.prompting ? -0.18 : 0

			Behavior on blur {
				NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
			}
			Behavior on brightness {
				NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
			}
			Behavior on saturation {
				NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
			}
		}

		// A click anywhere is one of the two ways into the password field. Sits
		// under the content so buttons drawn on top still get their own clicks.
		MouseArea {
			anchors.fill: parent
			onClicked: {
				Lock.prompt();
				field.forceActiveFocus();
			}
		}

		// ---- clock ----
		ColumnLayout {
			id: face

			anchors.horizontalCenter: parent.horizontalCenter
			anchors.top: parent.top
			anchors.topMargin: Math.round(surface.height * 0.12)

			spacing: 2

			Label {
				Layout.alignment: Qt.AlignHCenter
				text: Qt.formatDateTime(clock.date, "HH:mm")
				color: "#ffffff"
				font.pixelSize: 116
				font.weight: Font.DemiBold
				// A proportional clock jitters as the digits change width;
				// fixed advances hold every glyph in place.
				font.features: ({ "tnum": 1 })
			}

			Label {
				Layout.alignment: Qt.AlignHCenter
				text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
				color: "#d8d8d8"
				font.pixelSize: Config.fontSize + 6
			}
		}

		// ---- idle: calendar and notifications ----
		// Faded out rather than unloaded, so nothing reflows as the states
		// swap and the calendar does not have to be rebuilt on every escape.
		RowLayout {
			id: info

			anchors.horizontalCenter: parent.horizontalCenter
			anchors.top: face.bottom
			anchors.topMargin: 34

			spacing: 14

			opacity: surface.prompting ? 0 : 1
			visible: opacity > 0
			Behavior on opacity {
				NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
			}

			Calendar {
				Layout.alignment: Qt.AlignTop
				today: clock.date
				// The date is already spelled out under the clock.
				showToday: false
			}

			LockNotifications {
				Layout.alignment: Qt.AlignTop
				visible: Notifs.count > 0
			}
		}

		// ---- prompting: who, and the password ----
		ColumnLayout {
			id: auth

			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: Math.round(surface.height * 0.16)

			spacing: 12

			// Kept visible so the field can hold the keyboard even while the
			// card is invisible: the first keystroke has to land somewhere, and
			// that keystroke is what brings the card up.
			opacity: surface.prompting ? 1 : 0
			Behavior on opacity {
				NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
			}

			// ---- identity ----
			RowLayout {
				Layout.alignment: Qt.AlignHCenter
				spacing: 10

				Rectangle {
					Layout.preferredWidth: 44
					Layout.preferredHeight: 44
					radius: 22
					color: Qt.rgba(1, 1, 1, 0.14)
					border.width: 1
					border.color: Qt.rgba(1, 1, 1, 0.24)

					Label {
						anchors.centerIn: parent
						text: Config.icons.user
						color: "#ffffff"
						font.pixelSize: Config.fontSize + 6
					}
				}

				ColumnLayout {
					spacing: 0

					Label {
						text: Lock.user
						color: "#ffffff"
						font.pixelSize: Config.fontSize + 3
						font.weight: Font.DemiBold
					}

					Label {
						// Named, not chosen: which session is running was
						// decided at login, and this only reports it.
						text: Lock.session + " session"
						color: "#c0c0c0"
						font.pixelSize: Config.fontSize - 2
					}
				}
			}

			// ---- password ----
			Rectangle {
				id: box

				Layout.alignment: Qt.AlignHCenter
				Layout.preferredWidth: 340
				Layout.preferredHeight: 46

				radius: 23
				color: Qt.rgba(0, 0, 0, 0.45)
				border.width: 1
				border.color: Lock.error ? Config.red
					: field.activeFocus ? Config.accent
					: Qt.rgba(1, 1, 1, 0.25)

				Behavior on border.color { ColorAnimation { duration: 160 } }

				// Shaken on a rejection, which reads as "wrong" faster than
				// any message can be looked at.
				property real shake: 0
				transform: Translate { x: box.shake }

				SequentialAnimation {
					id: shakeAnim

					loops: 2
					NumberAnimation {
						target: box; property: "shake"; to: 9
						duration: 45; easing.type: Easing.OutSine
					}
					NumberAnimation {
						target: box; property: "shake"; to: -9
						duration: 90; easing.type: Easing.InOutSine
					}
					NumberAnimation {
						target: box; property: "shake"; to: 0
						duration: 45; easing.type: Easing.InSine
					}
				}

				Connections {
					target: Lock

					function onFailed() {
						shakeAnim.restart();
						field.text = "";
					}

					// Surfaces are normally torn down with the lock, but a
					// reused one must not come back holding what was typed
					// into it last time.
					function onLockedChanged() {
						if (!Lock.locked) return;
						field.text = "";
						field.forceActiveFocus();
					}
				}

				Label {
					anchors.left: parent.left
					anchors.leftMargin: 16
					anchors.verticalCenter: parent.verticalCenter

					text: Lock.authenticating ? Config.icons.spinner : Config.icons.key
					color: Lock.authenticating ? Config.accent : "#b8b8b8"
					font.pixelSize: Config.fontSize
				}

				TextInput {
					id: field

					anchors.fill: parent
					anchors.leftMargin: 40
					anchors.rightMargin: 40

					color: "#ffffff"
					font.family: Config.font
					font.pixelSize: Config.fontSize + 1
					verticalAlignment: TextInput.AlignVCenter
					clip: true

					echoMode: TextInput.Password
					passwordCharacter: "●"
					// Straight to dots. The brief plain-text reveal Qt does by
					// default is a shoulder-surfing hole on a screen that is,
					// by definition, unattended.
					passwordMaskDelay: 0

					enabled: !Lock.authenticating
					// Holds the keyboard for the whole life of the surface, not
					// only while the card is showing: typing on the clock is
					// what raises the card, and the character that raised it
					// has to be kept.
					focus: true

					// textEdited, not textChanged: this fires only for keys the
					// person actually pressed. On textChanged it would also fire
					// when a rejection resets the field, and wipe the very error
					// message that reset was reporting.
					onTextEdited: {
						if (text.length > 0) Lock.prompt();
						if (Lock.error) Lock.error = "";
					}

					onAccepted: {
						// Enter on the bare clock opens the field rather than
						// submitting nothing.
						if (!Lock.prompting) {
							Lock.prompt();
							return;
						}
						Lock.submit(field.text);
						// Handed over; there is no reason for a copy to sit in a
						// text field for the length of the PAM round trip, let
						// alone past a successful unlock.
						field.text = "";
					}

					Keys.onEscapePressed: {
						field.text = "";
						Lock.dismiss();
					}

					// Placeholder, drawn rather than set: TextInput has none.
					Label {
						anchors.verticalCenter: parent.verticalCenter
						visible: field.text.length === 0 && !Lock.authenticating
						text: "Password"
						color: "#8a8a8a"
						font.pixelSize: Config.fontSize
					}
				}

				// Submit, for a pointer-only unlock.
				MouseArea {
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					anchors.rightMargin: 8

					width: 30
					height: 30
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					enabled: !Lock.authenticating
					onClicked: {
						Lock.submit(field.text);
						field.text = "";
					}

					Rectangle {
						anchors.fill: parent
						radius: 15
						color: parent.containsMouse
							? Qt.rgba(1, 1, 1, 0.16) : "transparent"
					}

					Label {
						anchors.centerIn: parent
						text: Config.icons.arrowRight
						color: field.text.length > 0 ? Config.accent : "#8a8a8a"
						font.pixelSize: Config.fontSize - 1
					}
				}
			}

			// ---- message ----
			Label {
				Layout.alignment: Qt.AlignHCenter
				Layout.preferredHeight: 18

				text: Lock.error ? Lock.error
					: Lock.authenticating ? "Checking…"
					: "Esc to go back"
				color: Lock.error ? Config.red : "#b0b0b0"
				font.pixelSize: Config.fontSize - 2
			}
		}

		// ---- idle hint ----
		Label {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: Math.round(surface.height * 0.16) + 22

			text: Config.icons.lock + "   Press any key or click to unlock"
			color: "#c8c8c8"
			font.pixelSize: Config.fontSize

			opacity: surface.prompting ? 0 : 1
			visible: opacity > 0
			Behavior on opacity {
				NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
			}
		}

		// Focus can be lost when the surface is reconfigured — a monitor
		// waking, a resolution change. Without this the lock screen would sit
		// there swallowing keystrokes with nowhere to put them.
		onVisibleChanged: if (visible) field.forceActiveFocus()
		Component.onCompleted: field.forceActiveFocus()
	}

	// Notifications received while locked, shown beside the calendar.
	component LockNotifications: Rectangle {
		id: notifs

		readonly property int shown: Math.min(4, Notifs.count)

		implicitWidth: 320
		implicitHeight: list.implicitHeight + Config.padding * 2

		radius: Config.radius
		color: Config.bg
		border.width: 1
		border.color: Config.border

		ColumnLayout {
			id: list

			anchors.fill: parent
			anchors.margins: Config.padding
			spacing: 8

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Label {
					text: Config.icons.bell
					color: Config.accent
					font.pixelSize: Config.fontSize - 2
				}

				Label {
					Layout.fillWidth: true
					text: "Notifications"
					color: Config.accent
				}

				Label {
					text: Notifs.count
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
				}
			}

			Repeater {
				model: notifs.shown

				ColumnLayout {
					id: entry

					required property int index
					readonly property var notif: Notifs.history[entry.index] ?? null

					Layout.fillWidth: true
					spacing: 0
					visible: entry.notif !== null

					RowLayout {
						Layout.fillWidth: true
						spacing: 6

						Rectangle {
							Layout.preferredWidth: 6
							Layout.preferredHeight: 6
							radius: 3
							color: entry.notif?.urgency === NotificationUrgency.Critical
								? Config.red : Config.accent
						}

						Label {
							Layout.fillWidth: true
							Layout.minimumWidth: 0
							text: entry.notif?.summary ?? ""
							elide: Text.ElideRight
							font.pixelSize: Config.fontSize - 1
						}

						Label {
							text: entry.notif?.appName ?? ""
							color: Config.fgDim
							font.pixelSize: Config.fontSize - 4
						}
					}

					Label {
						Layout.fillWidth: true
						Layout.leftMargin: 12
						Layout.minimumWidth: 0

						text: (entry.notif?.body ?? "").replace(/<[^>]*>/g, "").trim()
						visible: text.length > 0
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
						elide: Text.ElideRight
						maximumLineCount: 1
					}
				}
			}

			Label {
				Layout.fillWidth: true
				visible: Notifs.count > notifs.shown
				text: "+" + (Notifs.count - notifs.shown) + " more"
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
			}
		}
	}
}
