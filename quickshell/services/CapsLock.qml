pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether caps lock is on, read from the keyd virtual keyboard's LED. Every
// key reaches niri through that device, so its LED is the state niri holds.
//
// sysfs sends no change notifications, so the LED is polled; a reload of one
// tiny file is cheap. Its inputN number changes whenever keyd restarts, so a
// failed read goes back to looking the LED up by device name.
Singleton {
	id: root

	property bool on: false
	property string ledPath: ""

	Process {
		id: find

		running: true
		command: ["sh", "-c",
			"grep -lx 'keyd virtual keyboard' /sys/class/leds/*::capslock/device/name | head -n1"]

		stdout: StdioCollector {
			onStreamFinished: {
				const name = this.text.trim();
				root.ledPath = name.length > 0 ? name.replace(/device\/name$/, "brightness") : "";
			}
		}
	}

	FileView {
		id: led

		path: root.ledPath
		printErrors: false

		onLoaded: root.on = led.text().trim() !== "0"
		onLoadFailed: {
			root.on = false;
			root.ledPath = "";
		}
	}

	Timer {
		interval: 200
		running: true
		repeat: true
		onTriggered: {
			if (root.ledPath.length > 0) led.reload();
			else if (!find.running) find.running = true;
		}
	}
}
