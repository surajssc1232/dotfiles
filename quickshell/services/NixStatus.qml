pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The state of the NixOS system: current generation, when it was built,
// whether the config has been edited since, how old the flake inputs are,
// and how big the store is. Read-only; the rebuild and garbage-collect
// buttons open a terminal so sudo can ask for the password there.
Singleton {
	id: root

	readonly property string flakeDir: Quickshell.env("HOME") + "/dotfiles/nixos"

	property int generation: 0
	property int generations: 0
	property real builtAt: 0          // seconds since epoch
	property real editedAt: 0         // newest .nix / flake.lock in flakeDir
	readonly property bool pending: root.editedAt > root.builtAt + 1 && root.builtAt > 0

	// [{ name, age (seconds) }], nixpkgs first.
	property var inputs: []

	property real storeBytes: -1      // -1 = not measured yet
	property bool measuring: false

	function refresh() {
		info.running = true;
	}

	function measureStore() {
		if (root.measuring) return;
		root.measuring = true;
		store.running = true;
	}

	function ago(seconds: real): string {
		if (seconds < 0) return "—";
		if (seconds < 3600) return Math.max(1, Math.round(seconds / 60)) + "m";
		if (seconds < 86400) return Math.round(seconds / 3600) + "h";
		return Math.round(seconds / 86400) + "d";
	}

	function terminal(script: string) {
		Quickshell.execDetached({ command: ["foot", "--app-id=nix-status", "sh", "-c",
			script + '; echo; printf "Done, press Enter to close"; read _'] });
	}

	function rebuild() {
		root.terminal("sudo nixos-rebuild switch --flake " + root.flakeDir);
	}

	function update() {
		root.terminal("cd " + root.flakeDir + " && nix flake update");
	}

	function collectGarbage() {
		root.terminal("sudo nix-collect-garbage -d && nix-collect-garbage -d");
	}

	Process {
		id: info

		command: ["sh", "-c",
			'p=/nix/var/nix/profiles; '
			+ 'readlink $p/system | sed "s/[^0-9]//g"; '
			+ 'ls -d $p/system-*-link | wc -l; '
			+ 'stat -c %Y $p/system; '
			+ 'find "$1" -maxdepth 2 \\( -name "*.nix" -o -name flake.lock \\) -printf "%T@\\n" | sort -n | tail -n1; '
			+ 'cat "$1/flake.lock"', "sh", root.flakeDir]

		stdout: StdioCollector {
			onStreamFinished: {
				const lines = this.text.split("\n");
				root.generation = parseInt(lines[0]) || 0;
				root.generations = parseInt(lines[1]) || 0;
				root.builtAt = parseFloat(lines[2]) || 0;
				root.editedAt = parseFloat(lines[3]) || 0;
				try {
					const lock = JSON.parse(lines.slice(4).join("\n"));
					const now = Date.now() / 1000;
					const roots = lock.nodes?.root?.inputs ?? {};
					root.inputs = Object.keys(roots)
						.map(name => ({ name: name, mod: lock.nodes[roots[name]]?.locked?.lastModified ?? 0 }))
						.filter(i => i.mod > 0)
						.map(i => ({ name: i.name, age: now - i.mod }))
						.sort((a, b) => (b.name === "nixpkgs") - (a.name === "nixpkgs") || a.name.localeCompare(b.name));
				} catch (err) {
					root.inputs = [];
				}
			}
		}
	}

	// du over the whole store takes a few seconds, so it only runs on demand.
	Process {
		id: store

		command: ["sh", "-c", "du -sb /nix/store 2>/dev/null | cut -f1"]

		stdout: StdioCollector {
			onStreamFinished: {
				root.storeBytes = parseFloat(this.text) || -1;
				root.measuring = false;
			}
		}
	}

	// The config is edited often and rebuilt rarely; a minute is plenty.
	Timer {
		interval: 60000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: root.refresh()
	}
}
