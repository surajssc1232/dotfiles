pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Rolling CPU, memory and network history for the desktop graphs.
// One sample a second, the last `length` kept.
Singleton {
	id: root

	readonly property int length: 60

	property var cpu: []      // percent
	property var mem: []      // percent
	property var down: []     // bytes/s
	property var up: []       // bytes/s

	property real lastIdle: 0
	property real lastTotal: 0
	property real lastRx: -1
	property real lastTx: -1

	function push(list, value) {
		const next = list.concat([value]);
		return next.length > root.length ? next.slice(next.length - root.length) : next;
	}

	function human(bytes: real): string {
		const units = ["B", "K", "M", "G"];
		let i = 0;
		while (bytes >= 1024 && i < units.length - 1) { bytes /= 1024; i++; }
		return (bytes < 10 && i > 0 ? bytes.toFixed(1) : Math.round(bytes)) + units[i];
	}

	Timer {
		interval: 1000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: sampler.running = true
	}

	Process {
		id: sampler

		command: ["sh", "-c", "head -n1 /proc/stat; head -n3 /proc/meminfo; tail -n +3 /proc/net/dev"]

		stdout: StdioCollector {
			onStreamFinished: root.parse(this.text)
		}
	}

	function parse(out: string) {
		const lines = out.trim().split("\n");
		if (lines.length < 4) return;

		const cols = lines[0].split(/\s+/).slice(1).map(Number);
		const idle = cols[3] + (cols[4] ?? 0);
		const total = cols.reduce((a, b) => a + b, 0);
		if (root.lastTotal > 0 && total > root.lastTotal)
			root.cpu = root.push(root.cpu,
				Math.round((1 - (idle - root.lastIdle) / (total - root.lastTotal)) * 100));
		root.lastIdle = idle;
		root.lastTotal = total;

		const num = l => Number(l.split(/\s+/)[1]);
		const memTotal = num(lines[1]);
		if (memTotal > 0) root.mem = root.push(root.mem, Math.round((1 - num(lines[3]) / memTotal) * 100));

		// Every interface but loopback and virtual bridges.
		let rx = 0, tx = 0;
		for (const l of lines.slice(4)) {
			const [name, rest] = l.split(":");
			const iface = (name ?? "").trim();
			if (!rest || iface === "lo" || /^(veth|docker|br-|virbr)/.test(iface)) continue;
			const f = rest.trim().split(/\s+/).map(Number);
			rx += f[0];
			tx += f[8];
		}
		if (root.lastRx >= 0) {
			root.down = root.push(root.down, Math.max(0, rx - root.lastRx));
			root.up = root.push(root.up, Math.max(0, tx - root.lastTx));
		}
		root.lastRx = rx;
		root.lastTx = tx;
	}
}
