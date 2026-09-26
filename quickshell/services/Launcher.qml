pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Application launcher: the catalogue, the ranking, and what Enter does.
//
// Nothing here draws; modules/Launcher.qml is the surface. Keeping the two
// apart means the ranking can be exercised from the bar or over IPC without a
// window on screen, which is the only practical way to tune it.
//
// A leading punctuation character picks a mode, the way fuzzel's sibling tools
// do it — see `mode` below. Everything else is an application search.
Singleton {
	id: root

	property bool open: false
	property string query: ""
	property int index: 0

	// How many entries a use is worth, and the ceiling on that bonus. High
	// enough that the app you always mean wins a tie, low enough that it can
	// never beat a name that actually starts with what you typed.
	readonly property int useWeight: 10
	readonly property int useCeiling: 12

	readonly property string mode: {
		const q = root.query;
		if (q.startsWith(">")) return "run";
		if (q.startsWith("=")) return "calc";
		if (q.startsWith("@")) return "window";
		if (q.startsWith("!")) return "command";
		if (q.startsWith(";")) return "clip";
		if (q.startsWith("/")) return "file";
		if (q.startsWith(":")) return "emoji";
		if (q.startsWith("%")) return "unit";
		if (q.startsWith("&")) return "bt";
		if (q.startsWith("?")) return "help";
		return "app";
	}

	// The query with its mode prefix removed.
	readonly property string term:
		(root.mode === "app" ? root.query : root.query.slice(1)).trim()

	readonly property var modeLabel: ({
		app: "Applications", run: "Run", calc: "Calculator",
		window: "Windows", command: "Commands", clip: "Clipboard",
		file: "Files", emoji: "Emoji", unit: "Failed units",
		bt: "Bluetooth", help: "Modes"
	})

	readonly property var modeIcon: ({
		app: Config.icons.apps, run: Config.icons.rocket,
		calc: Config.icons.calculator, window: Config.icons.window,
		command: Config.icons.settings, clip: Config.icons.clipboard,
		file: Config.icons.inbox, emoji: Config.icons.emoji,
		unit: Config.icons.settings, bt: Config.icons.bluetooth,
		help: Config.icons.question
	})

	readonly property var modePlaceholder: ({
		app: "Search applications", run: "Command to run",
		calc: "Expression", window: "Open windows",
		command: "Shell commands", clip: "Clipboard history",
		file: "Find a file under ~", emoji: "Search emoji by name",
		unit: "Failed systemd units", bt: "Connect a device",
		help: "Modes"
	})

	// What the delegate should highlight in each row. Only the modes that
	// actually match against the row's name have anything to mark up.
	readonly property string highlightTerm:
		["app", "command", "clip", "file", "run", "emoji", "unit", "bt"]
			.indexOf(root.mode) !== -1
			? root.term.toLowerCase() : ""

	// Keeps the clipboard watcher alive. Quickshell only builds a singleton
	// once something refers to it, and a history that starts recording the
	// first time you go looking for it is not a history.
	readonly property int clipCount: Clipboard.entries.length

	// The file mode's search term, pushed down rather than pulled: the search
	// starts a process, and it must not run while some other mode is typed in.
	Binding {
		target: FileSearch
		property: "query"
		value: root.mode === "file" ? root.term : ""
	}

	// ---- catalogue ----
	//
	// Rebuilt only when the set of installed applications changes, with every
	// searchable field folded to lower case up front: the alternative is
	// lower-casing five fields per app on every keystroke, which at a few
	// hundred entries is enough to be felt while typing.
	readonly property var appCatalog: {
		const out = [];
		const seen = ({});

		for (const e of DesktopEntries.applications.values) {
			if (!e || e.noDisplay) continue;
			// The same app is often installed both system-wide and in the
			// user profile; the id is what makes those one entry.
			if (seen[e.id]) continue;
			seen[e.id] = true;

			const keywords = (e.keywords ?? []).join(" ");
			out.push({
				kind: "app",
				key: e.id,
				name: e.name,
				detail: e.genericName || e.comment || "",
				iconName: e.icon ?? "",
				glyph: Config.icons.apps,
				entry: e,
				hay: ({
					name: (e.name ?? "").toLowerCase(),
					generic: (e.genericName ?? "").toLowerCase(),
					keywords: keywords.toLowerCase(),
					comment: (e.comment ?? "").toLowerCase(),
					id: (e.id ?? "").toLowerCase()
				})
			});

			// Desktop actions — "New Window", "New Private Window" and so on.
			// They are only reachable once something has been typed, so an
			// empty launcher still lists one row per application.
			for (const a of (e.actions ?? [])) {
				out.push({
					kind: "action",
					key: e.id + ":" + a.id,
					name: a.name,
					detail: e.name,
					iconName: a.icon || e.icon || "",
					glyph: Config.icons.arrowRight,
					action: a,
					entry: e,
					hay: ({
						name: (e.name + " " + a.name).toLowerCase(),
						generic: (a.name ?? "").toLowerCase(),
						keywords: "", comment: "",
						id: (e.id ?? "").toLowerCase()
					})
				});
			}
		}
		return out;
	}

	// The shell's own commands, searchable next to the applications. Cheap to
	// rebuild, and it has to be: the names change as things are toggled, so
	// this list is rebuilt every time one of them flips.
	readonly property var commandCatalog: LauncherActions.all.map(a => ({
		kind: "command",
		key: "cmd:" + a.id,
		name: a.name,
		detail: a.detail,
		iconName: "",
		glyph: a.glyph,
		act: a,
		hay: ({
			name: a.name.toLowerCase(),
			generic: (a.detail ?? "").toLowerCase(),
			keywords: "shell setting toggle",
			comment: "",
			id: a.id.toLowerCase()
		})
	}))

	readonly property var catalog: root.appCatalog.concat(root.commandCatalog)

	// ---- scoring ----
	//
	// Every match is ranked, never merely filtered: a launcher that returns
	// the right application in seventh place is a launcher you stop trusting.
	// The tiers below are ordered by how deliberate the match looks — a name
	// you typed the start of beats one you typed the middle of, which beats a
	// subsequence scattered through it.
	function fieldScore(hay: string, needle: string, fuzzy: bool): int {
		if (!hay) return -1;

		const at = hay.indexOf(needle);
		if (at === 0) return hay.length === needle.length ? 1000 : 900;
		if (at > 0) {
			const before = hay.charAt(at - 1);
			// A match starting a later word is nearly as good as one starting
			// the name: "code" in "Visual Studio Code" is not a coincidence.
			if (/[\s\-_.:/()]/.test(before)) return 800;
			return 700 - Math.min(at, 80);
		}
		return fuzzy ? root.subsequence(hay, needle) : -1;
	}

	// Characters in order but not adjacent: "frfx" for Firefox. Scored well
	// below any substring hit, and rewarded for runs and for landing on word
	// starts, so "gimp" prefers GIMP over a stray path through some other name.
	function subsequence(hay: string, needle: string): int {
		let at = 0;
		let first = -1;
		let last = -2;
		let points = 0;

		for (let i = 0; i < needle.length; i++) {
			const found = hay.indexOf(needle.charAt(i), at);
			if (found === -1) return -1;
			if (first === -1) first = found;

			if (found === last + 1) points += 14;
			else if (found === 0 || /[\s\-_.:/()]/.test(hay.charAt(found - 1))) points += 10;
			else points += 2;

			last = found;
			at = found + 1;
		}

		// Letters scattered across half a name are a coincidence; letters that
		// arrive together are a match. Charged per character of gap, because a
		// flat cap made every long name score the same.
		const span = last - first + 1;
		return 300 + points - Math.min((span - needle.length) * 4, 200);
	}

	// Weighted across the fields, best field wins. The penalties are what stop
	// a comment match from ever outranking a name match.
	function score(row, needle: string): int {
		const h = row.hay;
		let best = root.fieldScore(h.name, needle, true);
		best = Math.max(best, root.fieldScore(h.generic, needle, true) - 120);
		best = Math.max(best, root.fieldScore(h.id, needle, true) - 200);

		// Keywords and descriptions are matched literally only. Allowing a
		// subsequence through a whole sentence of prose meant "fire" pulled in
		// eight unrelated applications and no browser — the letters are always
		// in there somewhere if the text is long enough.
		best = Math.max(best, root.fieldScore(h.keywords, needle, false) - 180);
		best = Math.max(best, root.fieldScore(h.comment, needle, false) - 300);

		if (best < 0) return -1;
		// An action is a variant of its application, so it sits just under it
		// rather than pushing the application itself down the list.
		if (row.kind === "action") best -= 60;
		// A shell command loses a tie with an application. You reach for this
		// launcher to start something far more often than to flip a switch.
		if (row.kind === "command") best -= 20;
		return best + root.useBonus(row.key);
	}

	function useBonus(key: string): int {
		const n = root.history[key]?.n ?? 0;
		return Math.min(n, root.useCeiling) * root.useWeight;
	}

	// ---- results ----
	readonly property var results: {
		const needle = root.term.toLowerCase();

		if (root.mode === "help") return root.helpRows();
		if (root.mode === "calc") return root.calcRows(root.term);
		if (root.mode === "run") return root.runRows(root.term);
		if (root.mode === "window") return root.windowRows(needle);
		if (root.mode === "clip") return root.clipRows(needle);
		if (root.mode === "file") return root.fileRows();
		if (root.mode === "command") return root.commandRows(needle);
		if (root.mode === "emoji") return root.emojiRows(needle);
		if (root.mode === "unit") return root.unitRows(needle);
		if (root.mode === "bt") return root.btRows(needle);

		// Nothing typed: the applications you actually use, most first. This
		// is the state the launcher spends most of its life in, so it is worth
		// it being useful rather than alphabetical.
		if (!needle) {
			return root.catalog
				.filter(r => r.kind === "app")
				.sort((a, b) => (root.history[b.key]?.n ?? 0) - (root.history[a.key]?.n ?? 0)
					|| a.name.localeCompare(b.name));
		}

		const hits = [];
		for (const row of root.catalog) {
			const s = root.score(row, needle);
			if (s >= 0) hits.push({ row: row, score: s });
		}
		hits.sort((a, b) => b.score - a.score || a.row.name.localeCompare(b.row.name));
		const rows = hits.map(h => h.row);

		// An expression answers itself, without needing the = prefix. Guarded
		// on there being both a digit and an operator, so "7zip" stays an
		// application search and does not sprout a result of 7.
		if (/[0-9]/.test(needle) && /[-+*/^%]/.test(needle)) {
			const value = root.calc(root.term);
			if (value !== null) rows.unshift(root.calcRows(root.term)[0]);
		}

		// Never a dead end: if nothing here matches, the thing you typed is
		// probably somewhere else.
		if (rows.length === 0) rows.push(...root.webRows(root.term));

		return rows;
	}

	readonly property var selected: root.results[root.index] ?? null

	// The row the cursor is on, remembered by key rather than by position.
	//
	// A command entry rebuilds itself whenever the state it describes changes,
	// and several of them change on their own while the menu is open: the
	// recording clock ticks once a second, notification counts move, Wi-Fi
	// flips, the clipboard fills. Every one of those rebuilds `results`.
	// Resetting to 0 on any change would walk the selection back to the top
	// under the user's hands — hold ! open while recording and the cursor
	// jumps to "Lock screen" every second.
	property string anchorKey: ""
	property string anchorTerm: ""
	property string anchorMode: ""

	onIndexChanged: root.anchorKey = root.results[root.index]?.key ?? ""

	onResultsChanged: {
		// A new query really does invalidate the position: a selection made
		// three characters ago silently points at a different app.
		if (root.term !== root.anchorTerm || root.mode !== root.anchorMode) {
			root.anchorTerm = root.term;
			root.anchorMode = root.mode;
			root.index = 0;
			root.anchorKey = root.results[0]?.key ?? "";
			return;
		}

		// Same query, refreshed data: stay on the row the user picked, even if
		// it moved. Only fall back to the top if it is genuinely gone.
		const at = root.anchorKey
			? root.results.findIndex(r => r.key === root.anchorKey)
			: -1;
		root.index = at === -1 ? 0 : at;
	}

	// One row per mode, and committing one types its prefix for you.
	function helpRows(): var {
		return [
			{ kind: "help", key: "?app", name: "Applications", detail: "type anything",
			  glyph: Config.icons.apps, iconName: "", prefix: "" },
			{ kind: "help", key: "?run", name: "Run a command", detail: "> prefix",
			  glyph: Config.icons.rocket, iconName: "", prefix: ">" },
			{ kind: "help", key: "?calc", name: "Calculator", detail: "= prefix",
			  glyph: Config.icons.calculator, iconName: "", prefix: "=" },
			{ kind: "help", key: "?win", name: "Open windows", detail: "@ prefix",
			  glyph: Config.icons.window, iconName: "", prefix: "@" },
			{ kind: "help", key: "?cmd", name: "Shell commands", detail: "! prefix",
			  glyph: Config.icons.settings, iconName: "", prefix: "!" },
			{ kind: "help", key: "?clip", name: "Clipboard history", detail: "; prefix",
			  glyph: Config.icons.clipboard, iconName: "", prefix: ";" },
			{ kind: "help", key: "?file", name: "Files", detail: "/ prefix",
			  glyph: Config.icons.inbox, iconName: "", prefix: "/" },
			{ kind: "help", key: "?emoji", name: "Emoji", detail: ": prefix",
			  glyph: Config.icons.emoji, iconName: "", prefix: ":" },
			{ kind: "help", key: "?unit", name: "Failed units", detail: "% prefix",
			  glyph: Config.icons.settings, iconName: "", prefix: "%" },
			{ kind: "help", key: "?bt", name: "Bluetooth", detail: "& prefix",
			  glyph: Config.icons.bluetooth, iconName: "", prefix: "&" }
		];
	}

	// The ! mode searches the same commands as a plain search, plus the ones
	// that end the session — those are only ever reached deliberately.
	function commandRows(needle: string): var {
		const rows = LauncherActions.withSession.map(a => ({
			kind: "command", key: "cmd:" + a.id, name: a.name,
			detail: a.detail, iconName: "", glyph: a.glyph, act: a,
			hay: ({
				name: a.name.toLowerCase(),
				generic: (a.detail ?? "").toLowerCase(),
				keywords: "", comment: "", id: a.id.toLowerCase()
			})
		}));

		if (!needle) return rows;

		const hits = [];
		for (const row of rows) {
			const s = root.score(row, needle);
			if (s >= 0) hits.push({ row: row, score: s });
		}
		hits.sort((a, b) => b.score - a.score || a.row.name.localeCompare(b.row.name));
		return hits.map(h => h.row);
	}

	// Recency order, plain substring. Clipboard entries are arbitrary text —
	// ranking them by name shape would be ranking noise.
	function clipRows(needle: string): var {
		const rows = [];

		// In the order things were copied, images and text together.
		for (const entry of Clipboard.history) {
			if (entry.kind === "image") {
				const name = FileSearch.name(entry.path);
				if (needle && name.toLowerCase().indexOf(needle) === -1) continue;
				rows.push({
					kind: "clipImage", key: "clipimg:" + rows.length,
					name: "Image",
					detail: Qt.formatDateTime(new Date(entry.at), "d MMM hh:mm"),
					iconName: "", glyph: Config.icons.image,
					thumb: entry.path, path: entry.path
				});
			} else {
				const text = entry.text;
				if (needle && text.toLowerCase().indexOf(needle) === -1) continue;
				rows.push({
					kind: "clip", key: "clip:" + rows.length,
					name: Clipboard.preview(text),
					detail: Clipboard.describe(text),
					iconName: "", glyph: Config.icons.clipboard,
					text: text
				});
			}
		}
		return rows;
	}

	// Known devices, connected first — the point of this mode is reconnecting
	// a headset without opening a panel and aiming at a row.
	function btRows(needle: string): var {
		if (!Bt.available) {
			return [({
				kind: "info", key: "bt:none",
				name: "No Bluetooth adapter",
				detail: "Nothing to connect to",
				iconName: "", glyph: Config.icons.bluetooth
			})];
		}

		if (!Bt.enabled) {
			return [({
				kind: "btEnable", key: "bt:enable",
				name: "Turn Bluetooth on",
				detail: "The adapter is switched off",
				iconName: "", glyph: Config.icons.bluetooth
			})];
		}

		const rows = [];
		for (const device of Bt.devices) {
			if (!Bt.isKnown(device)) continue;
			const name = Bt.label(device);
			if (needle && name.toLowerCase().indexOf(needle) === -1) continue;
			rows.push({
				kind: "bt", key: "bt:" + device.address,
				name: name,
				detail: device.connected
					? Bt.status(device) + " · enter disconnects"
					: Bt.status(device) + " · enter connects",
				iconName: "", glyph: Bt.icon(device),
				device: device
			});
		}

		if (rows.length === 0) {
			rows.push({
				kind: "info", key: "bt:empty",
				name: "No paired devices",
				detail: "Pair one from the Bluetooth panel first",
				iconName: "", glyph: Config.icons.bluetooth
			});
		}

		return rows;
	}

	// Enter restarts; Delete opens the journal, because "why did it fail" is
	// the question you actually have.
	function unitRows(needle: string): var {
		const rows = [];
		for (const entry of Units.failed) {
			if (needle && entry.unit.toLowerCase().indexOf(needle) === -1) continue;
			rows.push({
				kind: "unit", key: "unit:" + entry.scope + ":" + entry.unit,
				name: entry.unit,
				detail: entry.scope + " · " + (entry.description || "failed")
					+ " · enter restarts, del shows the log",
				iconName: "", glyph: Config.icons.warning,
				entry: entry
			});
		}

		if (rows.length === 0) {
			rows.push({
				kind: "info", key: "unit:none",
				name: "Nothing has failed",
				detail: "All system and user units are healthy",
				iconName: "", glyph: Config.icons.check
			});
		}

		return rows;
	}

	// The glyph itself is the row's icon, so the list reads as emoji rather
	// than as a list of their names.
	function emojiRows(needle: string): var {
		return Emoji.search(needle, 60).map((e, i) => ({
			kind: "emoji", key: "emoji:" + i,
			name: e.name,
			detail: "Copy " + e.char,
			iconName: "", glyph: e.char,
			text: e.char
		}));
	}

	// Recently used files until something is typed, then an fd search.
	function fileRows(): var {
		const paths = root.term ? FileSearch.results : FileSearch.recent;
		return paths.map((path, i) => ({
			kind: "file", key: "file:" + i,
			name: FileSearch.name(path),
			detail: FileSearch.directory(path),
			iconName: "", glyph: Config.icons.inbox,
			path: path
		}));
	}

	// A bare domain is an address; anything else is a search.
	function webRows(term: string): var {
		if (!term) return [];

		const rows = [];
		if (/^([a-z][a-z0-9+.-]*:\/\/|[\w-]+(\.[\w-]+)+(\/|$))/i.test(term)) {
			const url = term.indexOf("://") === -1 ? "https://" + term : term;
			rows.push({ kind: "url", key: "url", name: term, detail: "Open in the browser",
				iconName: "", glyph: Config.icons.arrowRight, url: url });
		}

		rows.push({
			kind: "url", key: "web", name: term,
			detail: "Search the web", iconName: "", glyph: Config.icons.search,
			url: "https://duckduckgo.com/?q=" + encodeURIComponent(term)
		});
		return rows;
	}

	// What you typed, then the two ways to run it, then everything you have
	// run before that still matches. Typing nothing lists the history alone,
	// which makes `>` on its own a usable list rather than an empty box.
	function runRows(cmd: string): var {
		const rows = [];

		if (cmd) {
			rows.push({ kind: "run", key: "run:" + cmd, name: cmd, detail: "Run",
				glyph: Config.icons.rocket, iconName: "", command: cmd });
			rows.push({ kind: "term", key: "term:" + cmd, name: cmd,
				detail: "Run in " + Config.terminal[0],
				glyph: Config.icons.terminal, iconName: "", command: cmd });
		}

		// Plain substring, in recency order. Commands are not prose and you
		// usually remember how one started, so ranking them the way
		// applications are ranked only makes the order harder to predict.
		const needle = cmd.toLowerCase();
		for (const past of root.commands) {
			if (past === cmd) continue;
			if (needle && past.toLowerCase().indexOf(needle) === -1) continue;
			rows.push({ kind: "run", key: "run:" + past, name: past,
				detail: "Recent", glyph: Config.icons.history,
				iconName: "", command: past });
		}

		return rows;
	}

	function windowRows(needle: string): var {
		return Windows.windows
			.filter(w => !needle
				|| (w.title ?? "").toLowerCase().indexOf(needle) !== -1
				|| (w.appId ?? "").toLowerCase().indexOf(needle) !== -1)
			.map((w, i) => ({
				kind: "window", key: "win" + i,
				name: w.title || w.appId || "Untitled",
				detail: w.appId ?? "",
				glyph: Config.icons.window,
				iconName: w.appId ?? "",
				window: w
			}));
	}

	function calcRows(expr: string): var {
		if (!expr) return [];

		const value = root.calc(expr);
		if (value === null)
			return [{ kind: "calcError", key: "calc", name: "…", iconName: "",
				detail: "Not a complete expression", glyph: Config.icons.calculator }];

		return [{ kind: "calc", key: "calc", name: root.formatNumber(value),
			detail: "Enter copies to the clipboard", iconName: "",
			glyph: Config.icons.calculator, value: value }];
	}

	// ---- calculator ----
	//
	// A hand-written parser rather than eval: the input is whatever is in the
	// search field, so it is never handed to anything that could run code.
	// Returns null for anything that does not parse, which is the normal state
	// while an expression is still being typed.
	function calc(src: string): var {
		const s = src.toLowerCase().replace(/\s+/g, "").replace(/,/g, "");
		if (!s) return null;

		let i = 0;

		const constants = ({ pi: Math.PI, e: Math.E, tau: Math.PI * 2 });
		const functions = ({
			sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, round: Math.round,
			floor: Math.floor, ceil: Math.ceil, sin: Math.sin, cos: Math.cos,
			tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
			exp: Math.exp, log: Math.log10, log2: Math.log2, ln: Math.log,
			sign: Math.sign
		});

		function fail() { throw new Error("parse"); }

		function expr() {
			let left = term();
			while (i < s.length) {
				const c = s.charAt(i);
				if (c === "+") { i++; left += term(); }
				else if (c === "-") { i++; left -= term(); }
				else break;
			}
			return left;
		}

		function term() {
			let left = unary();
			while (i < s.length) {
				const c = s.charAt(i);
				// x doubles as a multiplication sign; it is what people type.
				if (c === "*" || c === "x") { i++; left *= unary(); }
				else if (c === "/") { i++; left /= unary(); }
				else if (c === "%") { i++; left %= unary(); }
				else break;
			}
			return left;
		}

		function unary() {
			if (s.charAt(i) === "-") { i++; return -unary(); }
			if (s.charAt(i) === "+") { i++; return unary(); }
			return power();
		}

		// Right-associative, so 2^3^2 is 512 rather than 64.
		function power() {
			const base = atom();
			if (s.charAt(i) === "^") { i++; return Math.pow(base, unary()); }
			return base;
		}

		function atom() {
			if (i >= s.length) fail();

			if (s.charAt(i) === "(") {
				i++;
				const v = expr();
				if (s.charAt(i) !== ")") fail();
				i++;
				return v;
			}

			const number = /^[0-9]*\.?[0-9]+/.exec(s.slice(i));
			if (number) {
				i += number[0].length;
				return parseFloat(number[0]);
			}

			const word = /^[a-z][a-z0-9]*/.exec(s.slice(i));
			if (word) {
				const name = word[0];
				i += name.length;
				if (functions[name]) {
					if (s.charAt(i) !== "(") fail();
					i++;
					const v = functions[name](expr());
					if (s.charAt(i) !== ")") fail();
					i++;
					return v;
				}
				if (name in constants) return constants[name];
			}

			fail();
		}

		try {
			const value = expr();
			// Trailing junk means the expression is not finished, not that it
			// evaluated to what was parsed so far.
			if (i !== s.length) return null;
			if (!isFinite(value)) return null;
			return value;
		} catch (err) {
			return null;
		}
	}

	// ---- match highlighting ----
	//
	// Re-derived from the name rather than threaded out of the scorer, which
	// keeps the scorer to one job. A row that matched on a keyword highlights
	// nothing, which is honest: there is nothing in the name to point at.
	function escapeMarkup(text: string): string {
		return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
	}

	function highlight(text: string, needle: string, color: string): string {
		if (!needle || !text) return root.escapeMarkup(text ?? "");

		const open = '<font color="' + color + '"><b>';
		const shut = "</b></font>";
		const lower = text.toLowerCase();

		const at = lower.indexOf(needle);
		if (at !== -1) {
			return root.escapeMarkup(text.slice(0, at))
				+ open + root.escapeMarkup(text.slice(at, at + needle.length)) + shut
				+ root.escapeMarkup(text.slice(at + needle.length));
		}

		// The same walk the subsequence scorer does, marking what it lands on.
		let out = "";
		let i = 0;
		for (let c = 0; c < text.length; c++) {
			const ch = text.charAt(c);
			if (i < needle.length && ch.toLowerCase() === needle.charAt(i)) {
				out += open + root.escapeMarkup(ch) + shut;
				i++;
			} else {
				out += root.escapeMarkup(ch);
			}
		}
		return i === needle.length ? out : root.escapeMarkup(text);
	}

	function formatNumber(value: real): string {
		if (Number.isInteger(value)) return value.toString();
		// Floating point noise — 0.1 + 0.2 — is not a result anyone wants to
		// read, and ten places is well past any real precision here.
		return parseFloat(value.toFixed(10)).toString();
	}

	// ---- opening and closing ----
	function show(prefix: string) {
		// The bookmark file changes constantly and is only read on demand.
		FileSearch.refreshRecent();
		root.query = prefix ?? "";
		root.index = 0;
		root.open = true;
	}

	function toggle() {
		if (root.open) root.close();
		else root.show("");
	}

	function close() {
		root.open = false;
		// Cleared on the way out rather than on the way in: clearing at open
		// time leaves one frame showing the last search before the new one.
		root.query = "";
		root.index = 0;
	}

	// Icon theme lookups are synchronous and walk the theme directories, so
	// the same name is resolved once and remembered. A list being scrolled
	// rebuilds its rows constantly, and paying that cost per row per frame is
	// what made scrolling stutter.
	property var iconCache: ({})

	function icon(name: string): string {
		if (!name) return "";

		const hit = root.iconCache[name];
		if (hit !== undefined) return hit;

		const path = Quickshell.iconPath(name, true);
		root.iconCache[name] = path;
		return path;
	}

	function step(delta: int) {
		const n = root.results.length;
		if (n === 0) return;
		root.index = ((root.index + delta) % n + n) % n;
	}

	// Bounded, for PageUp/PageDown and Home/End, where wrapping would be
	// disorienting rather than helpful.
	function moveTo(target: int) {
		const n = root.results.length;
		if (n === 0) return;
		root.index = Math.max(0, Math.min(n - 1, target));
	}

	function commit() {
		const row = root.selected;
		if (!row) return;

		// A mode row only rewrites the query; there is nothing to launch.
		if (row.kind === "help") {
			root.query = row.prefix;
			root.index = 0;
			return;
		}

		if (row.kind === "calcError" || row.kind === "info") return;

		if (row.kind === "unit") {
			Units.restart(row.entry);
			root.close();
			return;
		}

		if (row.kind === "bt") {
			Bt.activate(row.device);
			root.close();
			return;
		}

		// Left open: turning the adapter on is a step towards picking
		// something, not the thing you came to do.
		if (row.kind === "btEnable") {
			Bt.setEnabled(true);
			return;
		}

		if (row.kind === "calc") {
			Clipboard.copy(root.formatNumber(row.value));
			root.close();
			return;
		}

		if (row.kind === "clipImage") {
			Clipboard.copyImage(row.path);
			root.close();
			return;
		}

		if (row.kind === "clip" || row.kind === "emoji") {
			Clipboard.copy(row.text);
			root.close();
			return;
		}

		// Focus is the exception to closing first: while this shell holds the
		// keyboard the compositor refuses to activate anything, and once the
		// surface is gone the request comes from an unfocused client and is
		// refused again. Only a request issued in the same breath as giving
		// the keyboard back is honoured — the same rule Windows.finish keeps.
		if (row.kind === "window") {
			row.window.activate();
			root.close();
			return;
		}

		// Everything else starts a process, and that wants the keyboard handed
		// back first, so the new window is what the compositor focuses.
		const kind = row.kind;
		const entry = row.entry ?? null;
		const action = row.action ?? null;
		const command = row.command ?? "";
		const act = row.act ?? null;
		const path = row.path ?? "";
		const url = row.url ?? "";

		// Commands keep their own history; folding them into the application
		// frecency map would fill it with one key per command ever typed.
		if (kind === "run" || kind === "term") root.rememberCommand(command);
		else root.remember(row.key);

		root.close();

		if (kind === "app" && entry) root.launch(entry, entry);
		else if (kind === "action" && action) root.launch(entry, action);
		else if (kind === "run") root.spawn(command);
		else if (kind === "term") root.spawnInTerminal(command);
		else if (kind === "command" && act) act.run();
		else if (kind === "file") FileSearch.open(path);
		else if (kind === "url") Quickshell.execDetached({ command: ["xdg-open", url] });
	}

	// Delete removes the selected row from whichever history it came out of.
	// Only history can be deleted — there is nothing sensible to do to an
	// application, and pressing Delete over one should not feel dangerous.
	function deleteSelected() {
		const row = root.selected;
		if (!row) return;

		if (row.kind === "clip") Clipboard.remove(row.text);
		else if (row.kind === "clipImage") Clipboard.removeImage(row.path);
		else if (row.kind === "unit") Units.journal(row.entry);
		else if (row.kind === "run" && row.detail === "Recent")
			root.forgetCommand(row.command);
	}

	// `what` is the entry or one of its actions; `entry` is always the entry,
	// because that is where Terminal= lives.
	//
	// A Terminal=true entry — btop, htop, an editor — has no window of its own.
	// DesktopEntry.execute() has no terminal to put it in, so it starts, finds
	// no tty and vanishes: the launcher looks like it did nothing at all.
	// Those get the configured terminal wrapped around them instead.
	function launch(entry, what) {
		if (!entry || !entry.runInTerminal) {
			what.execute();
			return;
		}

		const argv = Config.terminal.slice();
		for (const arg of what.command) argv.push(arg);

		root.detach(argv, entry.workingDirectory);
	}

	// setsid detaches, so what is started outlives this shell being restarted —
	// without it every launched program is a child of quickshell and dies with
	// it. DesktopEntry.execute() already does its own detaching, which is why
	// only the paths that go through Process come through here.
	function detach(argv, directory) {
		Quickshell.execDetached({
			command: argv,
			workingDirectory: directory || Quickshell.env("HOME")
		});
	}

	function spawn(command: string) {
		root.detach(["sh", "-c", command], "");
	}

	function spawnInTerminal(command: string) {
		// The shell is held open on exit: a command that fails instantly is
		// otherwise a terminal that flashes and vanishes with the error in it.
		const wrapped = command
			+ '; printf "\\n[exit %s] press enter" "$?"; read _';
		root.detach(Config.terminal.concat(["sh", "-c", wrapped]), "");
	}

	// ---- usage history ----
	//
	// Frequency only, deliberately: recency makes the top of an empty launcher
	// reshuffle every time it is opened, and a list that moves is a list you
	// have to read instead of aim at.
	property var history: ({})

	function remember(key: string) {
		const next = ({});
		for (const k in root.history) next[k] = root.history[k];
		next[key] = ({ n: (next[key]?.n ?? 0) + 1 });
		root.history = next;
		historyFile.setText(JSON.stringify(next));
	}

	function forgetCommand(cmd: string) {
		root.commands = root.commands.filter(c => c !== cmd);
		commandsFile.setText(JSON.stringify(root.commands));
	}

	function forget() {
		root.history = ({});
		historyFile.setText("{}");
		root.commands = [];
		commandsFile.setText("[]");
	}

	// ---- command history ----
	//
	// Most recent first, and capped: this is a convenience, not a shell
	// history, and a list long enough to scroll is one you stop reading.
	property var commands: []

	readonly property int commandLimit: 50

	function rememberCommand(cmd: string) {
		if (!cmd) return;
		root.commands = [cmd]
			.concat(root.commands.filter(c => c !== cmd))
			.slice(0, root.commandLimit);
		commandsFile.setText(JSON.stringify(root.commands));
	}

	FileView {
		id: commandsFile

		path: Quickshell.statePath("launcher-commands")
		blockLoading: true
		printErrors: false
	}

	FileView {
		id: historyFile

		path: Quickshell.statePath("launcher-history")
		blockLoading: true
		printErrors: false
	}

	Component.onCompleted: {
		try {
			const saved = JSON.parse(historyFile.text().trim() || "{}");
			if (saved && typeof saved === "object") root.history = saved;
		} catch (err) {
			// A corrupt history is not worth refusing to start over.
			root.history = ({});
		}

		try {
			const saved = JSON.parse(commandsFile.text().trim() || "[]");
			if (Array.isArray(saved)) root.commands = saved;
		} catch (err) {
			root.commands = [];
		}
	}

	IpcHandler {
		target: "launcher"

		function toggle(): void {
			root.toggle();
		}

		function open(): void {
			root.show("");
		}

		// Opens straight into a mode: `qs ipc call launcher mode =`.
		function mode(prefix: string): void {
			root.show(prefix);
		}

		function close(): void {
			root.close();
		}

		function forget(): void {
			root.forget();
		}
	}
}
