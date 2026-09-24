import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

// CPU load and memory usage, sampled straight from /proc every 3 seconds.
// The process list this used to open now lives in the control centre.
Pill {
	id: root

	property int cpu: 0
	property int mem: 0

	// Previous /proc/stat counters, used to turn totals into a percentage.
	property real lastIdle: 0
	property real lastTotal: 0

	Timer {
		interval: 3000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: sampler.running = true
	}

	Process {
		id: sampler
		command: ["sh", "-c", "head -n1 /proc/stat; head -n3 /proc/meminfo"]

		stdout: StdioCollector {
			onStreamFinished: root.parseSample(this.text)
		}
	}

	function parseSample(out: string) {
		const lines = out.trim().split("\n");
		if (lines.length < 4) return;

		const cols = lines[0].split(/\s+/).slice(1).map(Number);
		const idle = cols[3] + (cols[4] ?? 0);
		const total = cols.reduce((a, b) => a + b, 0);

		if (lastTotal > 0) {
			const dTotal = total - lastTotal;
			const dIdle = idle - lastIdle;
			if (dTotal > 0) cpu = Math.round((1 - dIdle / dTotal) * 100);
		}
		lastIdle = idle;
		lastTotal = total;

		const num = l => Number(l.split(/\s+/)[1]);
		const memTotal = num(lines[1]);
		const memAvailable = num(lines[3]);
		if (memTotal > 0) mem = Math.round((1 - memAvailable / memTotal) * 100);
	}

	Label {
		text: Config.icons.cpu
		color: Config.accent
	}
	Label {
		text: root.cpu + "%"
	}
	Label {
		text: Config.icons.ram
		color: Config.accent
	}
	Label {
		text: root.mem + "%"
	}
}
