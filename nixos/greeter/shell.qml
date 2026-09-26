//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

// The login screen.
//
// Deliberately standalone rather than importing the desktop shell: this runs as
// the unprivileged `greeter` user, which cannot read /home/suraj (0700) and has
// no business starting a notification server, a clipboard watcher or a network
// agent. So the palette below is a copy of the desktop's rather than a
// reference to it — the cost of keeping the two in step by hand is smaller than
// the cost of the greeter failing to come up.
//
// The visual language is the lock screen's on purpose: same clock, same avatar
// row, same rounded password box, same shake on a rejection. Authentication is
// the one real difference — the lock screen re-checks a password through PAM,
// while this hands it to greetd, which is what actually starts the session.
ShellRoot {
	id: root

	// ---- what to log in as, and into ----
	readonly property string user: "suraj"
	readonly property var sessionCommand: ["niri-session"]

	// ---- palette (Gruvbox Dark, mirroring Config.qml) ----
	readonly property color bg: "#282828"
	readonly property color accent: "#fe8019"
	readonly property color red: "#fb4934"
	readonly property string font: "JetBrainsMono Nerd Font"
	readonly property int fontSize: 13

	readonly property string iconKey: ""
	readonly property string iconUser: ""
	readonly property string iconSpinner: ""

	// ---- auth state ----
	// `awaiting` is greetd having asked for a password and not yet been given
	// one. The two arrive in either order — the prompt usually lands before
	// anything is typed, but not reliably — so a password typed early is held
	// in `pending` until there is somewhere to put it.
	property bool authenticating: false
	property bool awaiting: false
	property string pending: ""
	property string errorText: ""

	// Whether the password field is up. Idle is the clock and the date alone;
	// prompting brings the field in and blurs everything behind it. The same
	// two states the lock screen has, and for the same reason: most of the
	// time a login screen is just something you glance at.
	property bool prompting: false

	signal failed()

	function begin() {
		if (!Greetd.available) return;
		if (Greetd.state !== GreetdState.Inactive) return;
		root.awaiting = false;
		root.pending = "";
		Greetd.createSession(root.user);
	}

	// A click, or the first key pressed. Refused mid-authentication so the
	// card cannot be dismissed out from under an exchange already running.
	function prompt() {
		if (root.prompting) return;
		root.errorText = "";
		root.prompting = true;
	}

	function dismiss() {
		if (!root.prompting || root.authenticating) return;
		root.prompting = false;
		root.errorText = "";
	}

	function submit(password: string) {
		if (root.authenticating) return;
		if (!password) {
			root.errorText = "Enter your password";
			return;
		}

		root.errorText = "";
		root.authenticating = true;

		if (root.awaiting) {
			root.awaiting = false;
			Greetd.respond(password);
		} else {
			// The prompt has not arrived yet; onAuthMessage will send this.
			root.pending = password;
		}
	}

	Component.onCompleted: root.begin()

	// A greeter that spins forever tells you nothing and cannot be debugged
	// from the outside: its log is written as the `greeter` user, into a
	// runtime directory nothing else can read. So after a reasonable wait it
	// gives up and says where it got stuck, which at least names the step.
	Timer {
		id: watchdog

		interval: 12000
		running: root.authenticating
		onTriggered: {
			root.authenticating = false;
			root.errorText = "No answer from greetd (state " + Greetd.state + ")";
			// Whatever went wrong, the message is no use behind a black
			// curtain — lift it before saying anything.
			curtain.open();
			root.failed();
		}
	}

	Connections {
		target: Greetd

		function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool) {
			if (responseRequired) {
				if (root.pending !== "") {
					const p = root.pending;
					root.pending = "";
					Greetd.respond(p);
				} else {
					root.awaiting = true;
				}
				return;
			}

			// Anything greetd wants said that is not a request for input: an
			// expired account, a fingerprint reader waiting to be touched.
			if (error && message) root.errorText = message;
		}

		function onAuthFailure(message: string) {
			root.authenticating = false;
			root.pending = "";
			root.awaiting = false;
			root.errorText = message ? message : "Incorrect password";
			root.failed();

			// greetd tears the session down on a failure, so the next attempt
			// needs a fresh one or the field would sit there doing nothing.
			Greetd.createSession(root.user);
		}

		// No parameter: readyToLaunch() carries none. The version that took
		// one still ran — QML passes undefined for the extra — but it read as
		// though a failure could arrive here, and none ever can.
		// Fades to black first; the launch itself happens when the curtain is
		// down, in the animation's onFinished. Without that the greeter
		// vanishes mid-frame and the screen snaps to black while the session
		// starts behind it.
		function onReadyToLaunch() {
			curtain.close();
		}

		// Belt and braces: if the launch call above ever stops quitting on our
		// behalf, this still lets go of the socket.
		function onLaunched() {
			Qt.quit();
		}

		// Anything greetd rejects outright — a session that will not start, a
		// socket that died. Without this the greeter simply span.
		function onError(message: string) {
			root.authenticating = false;
			root.pending = "";
			root.awaiting = false;
			root.errorText = message ? message : "greetd reported an error";
			root.failed();
		}
	}

	PanelWindow {
		id: surface

		screen: Quickshell.screens[0] ?? null

		anchors {
			top: true
			bottom: true
			left: true
			right: true
		}

		color: root.bg
		WlrLayershell.layer: WlrLayer.Overlay
		// The greeter is the only thing on this compositor and it must have
		// the keyboard from the first frame: there is nowhere else to type.
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

		// ---- backdrop ----
		//
		// The greeter runs as the unprivileged `greeter` user and cannot read
		// /home/suraj, so it cannot open the desktop's wallpaper directly. The
		// shell copies the lock wallpaper into a world-readable directory and
		// writes its path here; if either is missing this falls through to the
		// flat colour above, which is what a first boot looks like.
		FileView {
			id: pointer

			path: "/var/lib/quickshell-greeter/current"
			blockLoading: true
			printErrors: false
		}

		readonly property string picture: pointer.text().trim()
			? "file://" + pointer.text().trim() : ""

		Image {
			id: backdrop

			anchors.fill: parent
			visible: false

			source: surface.picture
			fillMode: Image.PreserveAspectCrop
			asynchronous: true
			cache: false
		}

		MultiEffect {
			anchors.fill: parent

			source: backdrop
			visible: backdrop.status === Image.Ready

			// Softens once there is a password in the field, the same gesture
			// the lock screen makes: attention moves to what you are typing.
			blurEnabled: true
			blurMax: 48
			blur: root.prompting ? 1 : 0
			brightness: root.prompting ? -0.34 : -0.16
			saturation: root.prompting ? -0.18 : 0

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

		// One of the two ways in. Sits under the content, so the field itself
		// still gets its own clicks.
		MouseArea {
			anchors.fill: parent
			onClicked: {
				root.prompt();
				field.forceActiveFocus();
			}
		}

		Timer {
			id: clock

			property date date: new Date()

			interval: 1000
			running: true
			repeat: true
			triggeredOnStart: true
			onTriggered: clock.date = new Date()
		}

		// ---- clock ----
		ColumnLayout {
			anchors.horizontalCenter: parent.horizontalCenter
			anchors.top: parent.top
			anchors.topMargin: Math.round(surface.height * 0.14)

			spacing: 2

			Text {
				Layout.alignment: Qt.AlignHCenter
				text: Qt.formatDateTime(clock.date, "HH:mm")
				color: "#ffffff"
				font.family: root.font
				font.pixelSize: 116
				font.weight: Font.DemiBold
				// A proportional clock jitters as the digits change width.
				font.features: ({ "tnum": 1 })
			}

			Text {
				Layout.alignment: Qt.AlignHCenter
				text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
				color: "#d8d8d8"
				font.family: root.font
				font.pixelSize: root.fontSize + 6
			}
		}

		// ---- identity and password ----
		ColumnLayout {
			id: auth

			anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: Math.round(surface.height * 0.16)

			spacing: 12

			// Faded rather than hidden, and deliberately: the field has to keep
			// the keyboard while it is invisible, because the keystroke that
			// brings it up is the first character of the password and has to
			// land somewhere.
			opacity: root.prompting ? 1 : 0

			Behavior on opacity {
				NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
			}

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

					Text {
						anchors.centerIn: parent
						text: root.iconUser
						color: "#ffffff"
						font.family: root.font
						font.pixelSize: root.fontSize + 6
					}
				}

				ColumnLayout {
					spacing: 0

					Text {
						text: root.user
						color: "#ffffff"
						font.family: root.font
						font.pixelSize: root.fontSize + 3
						font.weight: Font.DemiBold
					}

					Text {
						text: "niri session"
						color: "#c0c0c0"
						font.family: root.font
						font.pixelSize: root.fontSize - 2
					}
				}
			}

			Rectangle {
				id: box

				Layout.alignment: Qt.AlignHCenter
				Layout.preferredWidth: 340
				Layout.preferredHeight: 46

				radius: 23
				color: Qt.rgba(0, 0, 0, 0.45)
				border.width: 1
				border.color: root.errorText ? root.red
					: field.activeFocus ? root.accent
					: Qt.rgba(1, 1, 1, 0.25)

				Behavior on border.color { ColorAnimation { duration: 160 } }

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
					target: root

					function onFailed() {
						shakeAnim.restart();
						field.text = "";
						field.forceActiveFocus();
					}
				}

				Text {
					anchors.left: parent.left
					anchors.leftMargin: 16
					anchors.verticalCenter: parent.verticalCenter

					text: root.authenticating ? root.iconSpinner : root.iconKey
					color: root.authenticating ? root.accent : "#b8b8b8"
					font.family: root.font
					font.pixelSize: root.fontSize

					RotationAnimation on rotation {
						running: root.authenticating
						loops: Animation.Infinite
						from: 0
						to: 360
						duration: 900
					}
				}

				TextInput {
					id: field

					anchors.fill: parent
					anchors.leftMargin: 40
					anchors.rightMargin: 40

					verticalAlignment: TextInput.AlignVCenter
					echoMode: TextInput.Password
					passwordCharacter: "•"
					// Room between the dots, which otherwise run together.
					font.letterSpacing: 4
					color: "#ffffff"
					font.family: root.font
					font.pixelSize: root.fontSize + 1
					enabled: !root.authenticating
					focus: true

					// The first key typed while idle is what raises the card,
					// and it is kept: textEdited fires only for keys a person
					// actually pressed, so a rejection clearing the field
					// cannot wipe the error it was reporting.
					onTextEdited: {
						if (field.text !== "") root.prompt();
						if (root.errorText !== "") root.errorText = "";
					}

					onAccepted: {
						// Enter on an idle screen asks for the password rather
						// than submitting an empty one.
						if (!root.prompting) {
							root.prompt();
							return;
						}
						root.submit(field.text);
					}

					// Back to the clock, and the backdrop comes back into
					// focus behind it.
					Keys.onEscapePressed: {
						field.text = "";
						root.dismiss();
					}

					Component.onCompleted: field.forceActiveFocus()

					Text {
						anchors.verticalCenter: parent.verticalCenter
						visible: field.text === "" && !root.authenticating
						text: "Password"
						color: "#8a8a8a"
						font.family: root.font
						font.pixelSize: root.fontSize + 1
					}
				}
			}

			Text {
				Layout.alignment: Qt.AlignHCenter
				Layout.preferredHeight: 16

				text: root.errorText
				color: root.red
				font.family: root.font
				font.pixelSize: root.fontSize - 2
			}

			// Only ever seen when this file is run outside greetd — which is
			// exactly when it needs saying, because nothing else would explain
			// why a correct password does nothing.
			Text {
				Layout.alignment: Qt.AlignHCenter
				visible: !Greetd.available
				text: "greetd is not available — this is a preview, login is inactive"
				color: "#c0c0c0"
				font.family: root.font
				font.pixelSize: root.fontSize - 2
			}
		}

		// ---- fade ----
		//
		// The greeter arrives out of a black screen and leaves into one, so
		// both ends are a fade rather than a cut. No MouseArea, so it never
		// takes a click even while it is opaque.
		Rectangle {
			id: curtain

			anchors.fill: parent
			color: "#000000"
			opacity: 1

			function open() { lift.restart(); }
			function close() { drop.restart(); }

			NumberAnimation {
				id: lift

				target: curtain
				property: "opacity"
				to: 0
				duration: 340
				easing.type: Easing.OutCubic
			}

			NumberAnimation {
				id: drop

				target: curtain
				property: "opacity"
				to: 1
				duration: 220
				easing.type: Easing.InCubic

				// The session starts behind a screen that is already black,
				// which is what makes the handover look deliberate rather
				// than like something crashed.
				//
				// quit is passed explicitly, and it is the whole reason a
				// correct password used to hang: greetd starts the session
				// only once the greeter has let go of the socket, so a greeter
				// that stays alive leaves greetd waiting forever with the
				// spinner still turning. The journal shows it plainly — a
				// working login logs "client loop failed: Broken pipe" (the
				// greeter exiting) immediately before "session opened for
				// user".
				onFinished: Greetd.launch(root.sessionCommand, [], true)
			}

			Component.onCompleted: curtain.open()
		}

	}
}
