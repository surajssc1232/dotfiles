import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

// Download and upload throughput, differentiated from /proc/net/dev.
Pill {
	id: root

	readonly property int sampleInterval: 2000

	property real down: 0        // bytes/second
	property real up: 0

	// Previous counters and the moment they were taken; the real elapsed time
	// is used rather than the timer interval, which drifts under load.
	property real lastRx: 0
	property real lastTx: 0
	property real lastAt: 0

	// Loopback inflates the numbers, and container/VPN/virtual interfaces
	// double-count traffic that already crossed a physical one.
	function counts(name: string): bool {
		return name !== "lo"
			&& !/^(docker|veth|br-|virbr|vmnet|tun|tap|wg|zt|lxc)/.test(name);
	}

	FileView {
		id: dev

		path: "/proc/net/dev"
		blockLoading: true
		printErrors: false
	}

	Timer {
		interval: root.sampleInterval
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			dev.reload();
			root.sample(dev.text());
		}
	}

	function sample(text: string) {
		let rx = 0;
		let tx = 0;

		// "  iface: rxBytes rxPackets ... txBytes txPackets ..." — the counters
		// start at column 1 after the name, with tx bytes ninth.
		for (const line of text.split("\n").slice(2)) {
			const parts = line.trim().split(/\s+/);
			if (parts.length < 10) continue;

			const name = parts[0].replace(/:$/, "");
			if (!root.counts(name)) continue;

			rx += Number(parts[1]);
			tx += Number(parts[9]);
		}

		const now = Date.now();
		const elapsed = (now - root.lastAt) / 1000;

		// Skip the first sample, and any where a counter went backwards —
		// an interface coming up resets it, which would read as a huge spike.
		if (root.lastAt > 0 && elapsed > 0 && rx >= root.lastRx && tx >= root.lastTx) {
			root.down = (rx - root.lastRx) / elapsed;
			root.up = (tx - root.lastTx) / elapsed;
		}

		root.lastRx = rx;
		root.lastTx = tx;
		root.lastAt = now;
	}

	// Never wider than five characters, which is what the label is sized for:
	// the unit steps up at 999 rather than 1024 so a reading can never reach
	// four digits and overflow into the module beside it.
	function format(bytes: real): string {
		const k = bytes / 1024;
		if (k < 1) return "0 K";
		if (k < 999.5)
			return (k < 10 ? k.toFixed(1) : Math.round(k).toString()) + " K";

		const m = k / 1024;
		if (m < 999.5)
			return (m < 10 ? m.toFixed(1) : Math.round(m).toString()) + " M";

		return (m / 1024).toFixed(1) + " G";
	}

	Label {
		text: Config.icons.down
		color: Config.green
		font.pixelSize: Config.fontSize - 3
	}

	Label {
		text: root.format(root.down)
		// Fixed width: this pill sits in a right-anchored row, so letting it
		// resize with the reading would nudge every module beside it twice a
		// second. The font is monospaced, so the widest value sets the width.
		Layout.preferredWidth: metrics.width
		horizontalAlignment: Text.AlignRight
	}

	Label {
		text: Config.icons.up
		color: Config.yellow
		font.pixelSize: Config.fontSize - 3
	}

	Label {
		text: root.format(root.up)
		Layout.preferredWidth: metrics.width
		horizontalAlignment: Text.AlignRight
	}

	TextMetrics {
		id: metrics

		font.family: Config.font
		font.pixelSize: Config.fontSize
		text: "999 M"
	}
}
