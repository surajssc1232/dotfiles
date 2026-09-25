pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji, searchable by name.
//
// The list is generated from Unicode's own emoji-test.txt and kept beside the
// config as data/emoji.txt — one "char<tab>name" per line. Shipping the data
// rather than reading it from a package means the picker cannot break when
// something unrelated is upgraded or removed.
Singleton {
	id: root

	// [{ char, name }]
	property var all: []

	readonly property bool ready: root.all.length > 0

	function search(needle: string, limit: int): var {
		if (!needle) return root.all.slice(0, limit);

		const hits = [];
		for (const entry of root.all) {
			const at = entry.name.indexOf(needle);
			if (at === -1) continue;

			// A name that starts with what you typed beats one that merely
			// contains it, and a word boundary beats the middle of a word.
			let score;
			if (entry.name === needle) score = 1000;
			else if (at === 0) score = 900;
			else if (entry.name.charAt(at - 1) === " ") score = 800;
			else score = 700 - Math.min(at, 60);

			hits.push({ entry: entry, score: score });
		}

		hits.sort((a, b) => b.score - a.score
			|| a.entry.name.length - b.entry.name.length);

		return hits.slice(0, limit).map(h => h.entry);
	}

	FileView {
		id: file

		path: Quickshell.shellPath("data/emoji.txt")
		printErrors: false

		onLoaded: {
			const out = [];
			for (const line of file.text().split("\n")) {
				const tab = line.indexOf("\t");
				if (tab === -1) continue;
				out.push({
					char: line.slice(0, tab),
					name: line.slice(tab + 1).toLowerCase()
				});
			}
			root.all = out;
		}
	}
}
