import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

// Only present while recording: a blinking dot, the elapsed time, and a click
// to stop. Recording with no visible sign of it is the thing to avoid.
Pill {
	id: root

	visible: Recorder.recording
	interactive: true
	background: Config.bgAlt

	onClicked: event => {
		if (event.button === Qt.RightButton) Recorder.cancel();
		else Recorder.stop();
	}

	Label {
		text: Recorder.finishing ? Config.icons.spinner : Config.icons.record
		color: Config.red
		font.pixelSize: Config.fontSize - 3

		SequentialAnimation on opacity {
			running: Recorder.recording && !Recorder.finishing
			loops: Animation.Infinite
			NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
			NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
		}
	}

	Label {
		text: Recorder.finishing ? "saving…" : Recorder.clock()
		color: Config.fg
	}
}
