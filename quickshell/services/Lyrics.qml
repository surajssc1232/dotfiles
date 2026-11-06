pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services

// Lyrics for whatever is playing, from lrclib.net, timed to the player.
//
// Works for any MPRIS player — Spotify, and YouTube or anything else playing
// in a browser — since all it needs is a title, an artist and a position.
//
// What leaves the machine: the title and artist of each new track, sent to
// lrclib.net, and only while the lyrics are shown. Answers are cached, so a
// song is asked about once; a miss is asked again after a few days in case
// someone has added it since. Config.lyrics = false stops all of it.
Singleton {
	id: root

	readonly property bool enabled: Config.lyrics

	// Whether the overlay is up. Nothing is fetched while it is not.
	property bool shown: Persist.get("lyricsShown", false)

	function toggle() {
		root.shown = !root.shown;
		Persist.set("lyricsShown", root.shown);
	}

	// The player that is playing, else one that is paused on something.
	readonly property var player: {
		const all = Mpris.players.values;
		return all.find(p => p.isPlaying)
			?? all.find(p => p.playbackState === MprisPlaybackState.Paused && p.trackTitle !== "")
			?? null;
	}

	readonly property string title: root.player?.trackTitle ?? ""
	readonly property string artist: root.player?.trackArtist ?? ""
	readonly property real length: root.player?.lengthSupported ? root.player.length : 0

	// Length is left out on purpose: a browser often reports it a moment
	// after the title, and that should not count as a second track.
	readonly property string key: root.title === "" ? "" : (root.artist + "\u0001" + root.title).toLowerCase()

	// idle · searching · synced · plain · instrumental · missing · error
	property string status: "idle"

	// [{ time, text }] in seconds, sorted. time is -1 throughout for plain lyrics.
	property var lines: []

	// Index into lines of the one being sung. Stays 0 for untimed lyrics.
	property int index: 0

	// Seconds added to the player's position for this track: positive brings
	// the lyrics sooner. Remembered per song.
	property real offset: 0

	// What lrclib matched, for the header: "Artist — Title".
	property string matched: ""

	readonly property bool synced: root.status === "synced"

	// "lrclib" or "tapped": where the timings came from.
	property string source: ""

	// The overlay follows a line, rather than leaving the page still, while
	// lyrics are timed or are being timed by hand.
	readonly property bool following: root.synced || root.timing

	// ---- following the track ----

	onKeyChanged: { root.lengthTries = 0; root.cancelTiming(); settle.restart(); }
	onShownChanged: if (root.shown) settle.restart()
	onEnabledChanged: settle.restart()

	// A browser can report the length well after the title. A match made
	// without it is a guess between every recording of the song — an album
	// cut and a music video with an intro — so look again once it is known.
	onLengthChanged: {
		if (root.length > 0 && root.searchedLength === 0 && root.key !== "" && !root.timing) settle.restart();
	}

	// Waits for the metadata to stop arriving piecemeal before looking it up.
	Timer {
		id: settle

		interval: 700
		onTriggered: root.load(false)
	}

	// The position is worked out by Quickshell from the last one the player
	// reported, so reading it is free; nothing is asked of the player here.
	Timer {
		interval: 120
		repeat: true
		running: root.shown && root.synced && (root.player?.isPlaying ?? false)
		triggeredOnStart: true
		onTriggered: root.follow()
	}

	// A seek while paused does not start the timer above.
	Connections {
		target: root.player
		ignoreUnknownSignals: true

		function onPositionChanged() { root.follow(); }
	}

	// Untimed lyrics are left alone: guessing the line from how far through
	// the track we are drifts at the first intro or solo, and a wrong line
	// lit up is worse than none.
	function follow() {
		if (!root.player || !root.synced || root.timing || root.lines.length === 0) return;
		const position = (root.player.positionSupported ? root.player.position : 0) + root.offset;
		let next = 0;
		let low = 0;
		let high = root.lines.length - 1;
		while (low <= high) {
			const mid = (low + high) >> 1;
			if (root.lines[mid].time <= position) { next = mid; low = mid + 1; }
			else high = mid - 1;
		}
		if (next !== root.index) root.index = next;
	}

	function nudge(seconds: real) {
		if (root.key === "" || root.timing) return;
		root.offset = Math.round((root.offset + seconds) * 100) / 100;
		const mine = root.tapped(root.key);
		const entry = mine ?? root.cached(root.key);
		if (entry) {
			entry.offset = root.offset;
			if (mine) root.keep(root.key, mine);
			else root.remember(root.key, entry);
		}
		root.follow();
	}

	// ---- looking up ----

	property int generation: 0

	// The length the current lyrics were chosen for; 0 if it was not known.
	property real searchedLength: -1
	property int lengthTries: 0

	function load(force: bool) {
		if (root.timing) return;
		root.generation++;
		root.index = 0;
		root.lines = [];
		root.matched = "";
		root.offset = 0;
		root.source = "";
		root.searchedLength = -1;

		if (!root.enabled || root.key === "") { root.status = "idle"; return; }

		// Timings tapped in by hand beat anything lrclib has.
		const mine = root.tapped(root.key);
		if (mine && !force) { root.apply(mine); return; }

		const entry = force ? null : root.cached(root.key);
		// Entries from older matching rules, and ones chosen before the
		// length was known, are looked up again.
		const stale = entry && (entry.v !== root.cacheVersion
			|| entry.status === "missing" && Date.now() - entry.at > root.missLife
			|| entry.status === "found" && !(entry.length > 0) && root.length > 0);
		if (entry && !stale) { root.apply(entry); return; }

		// Not shown: leave it until it is, rather than sending every track
		// that plays to lrclib for nothing.
		if (!root.shown) { root.status = "idle"; return; }

		root.status = "searching";

		// Give the length a few seconds to turn up before guessing without it.
		if (root.length <= 0 && root.lengthTries < 5) {
			root.lengthTries++;
			settle.restart();
			return;
		}

		root.searchedLength = root.length;
		root.search(root.generation);
	}

	function apply(entry) {
		root.offset = entry.offset ?? 0;
		root.matched = entry.matched ?? "";
		root.source = entry.source ?? "lrclib";
		root.searchedLength = entry.length ?? 0;
		if (entry.synced) {
			root.lines = root.parse(entry.synced);
			root.status = root.lines.length > 0 ? "synced" : "missing";
		} else if (entry.plain) {
			root.lines = entry.plain.split(/\r?\n/).map(l => l.trim())
				.filter((l, i, all) => l !== "" || (i > 0 && all[i - 1] !== ""))
				.map(l => ({ time: -1, text: l }));
			root.status = "plain";
		} else {
			root.status = entry.status === "instrumental" ? "instrumental" : "missing";
		}
		root.follow();
	}

	// One lookup is a few requests, tried in turn until one has timed
	// lyrics for a recording about as long as this one. Untimed lyrics are
	// kept as a fallback in case nothing better turns up.
	function search(token: int) {
		const pairs = root.candidates(root.title, root.artist);
		const artists = pairs.map(c => c.artist).filter(a => a !== "");

		const steps = pairs.map(c => ({ params: ["track_name=" + c.track, "artist_name=" + c.artist], want: c.track }));
		// Last, the title alone, for when the channel is a label rather than
		// the artist. Only ever a song title: searching for the artist alone
		// turns up their other songs, which are then "close enough".
		for (const track of new Set(pairs.map(c => c.track))) steps.push({ params: ["q=" + track], want: track });

		const job = { token: token, steps: steps, artists: artists, best: null, failed: false, key: root.key, length: root.length };
		root.step(job);
	}

	function step(job) {
		if (job.token !== root.generation) return;

		const next = job.steps.shift();
		if (!next || (job.best?.syncedLyrics && job.best.score < 5)) { root.finish(job); return; }

		const command = ["curl", "-sS", "--max-time", "10",
			"-A", "quickshell-lyrics (personal desktop widget)",
			"-G", "https://lrclib.net/api/search"];
		for (const p of next.params) command.push("--data-urlencode", p);

		request.createObject(root, {
			command: command,
			handle: text => {
				let results = null;
				try { results = JSON.parse(text); } catch (err) {}
				if (!Array.isArray(results)) job.failed = true;
				else {
					const pick = root.pick(results, next.want, job.artists, job.length);
					if (pick && (!job.best || pick.score < job.best.score)) job.best = pick;
				}
				root.step(job);
			}
		});
	}

	function finish(job) {
		const best = job.best;
		if (!best && job.failed) {
			root.status = "error";
			retry.restart();
			return;
		}

		const entry = {
			v: root.cacheVersion,
			at: Date.now(),
			status: !best ? "missing" : best.instrumental && !best.syncedLyrics && !best.plainLyrics ? "instrumental" : "found",
			synced: best?.syncedLyrics ?? "",
			plain: best?.syncedLyrics ? "" : (best?.plainLyrics ?? ""),
			matched: best ? (best.artistName + " — " + best.trackName) : "",
			length: job.length,
			offset: 0
		};
		root.remember(job.key, entry);
		if (job.key === root.key) root.apply(entry);
	}

	// The same song, by the closest recording in length, timed lyrics first.
	// lrclib's search is loose and happily returns the artist's other songs,
	// so the title has to really match. Anything far off in length is
	// another recording — a live take, an extended mix — whose timings would
	// be no use.
	//
	// Length alone is not enough, though: anyone can upload, and a broken
	// upload labelled with exactly the right length beats a good one that is
	// a second out. So timings are also judged on whether they cover the
	// song, and on whether other uploads agree with them — a popular song
	// usually has several, and the good ones match each other.
	function pick(results, want: string, artists: var, length: real): var {
		const usable = results.filter(r => (r.syncedLyrics || r.plainLyrics || r.instrumental)
			&& root.sameTitle(r.trackName, want));
		const shapes = usable.map(r => r.syncedLyrics ? root.shape(r.syncedLyrics) : null);
		const timed = shapes.filter(sh => sh !== null).length;

		let best = null;
		usable.forEach((r, i) => {
			const diff = length > 0 && r.duration ? Math.abs(r.duration - length) : 0;
			if (diff > 45) return;
			const byThem = artists.length === 0 || artists.some(a => root.similar(r.artistName, a));
			let score = diff + (r.instrumental ? 30 : 0) + (byThem ? 0 : 15);

			const sh = shapes[i];
			if (!sh) score += 20;
			else {
				const span = length > 0 ? length : (r.duration || 0);
				// Lines after the song has ended, or stopping well short of it.
				if (span > 0 && sh.last > span + 3) return;
				if (span > 0 && sh.last < span * 0.7) score += 25;
				if (sh.stacked) score += 10;

				const agree = shapes.filter((o, j) => j !== i && o
					&& Math.abs(o.first - sh.first) < 1.5 && Math.abs(o.last - sh.last) < 3).length;
				if (agree === 0 && timed >= 3) score += 15;
				score -= Math.min(agree, 5) * 0.5;
			}

			if (!best || score < best.score) best = Object.assign({ score: score }, r);
		});
		return best;
	}

	// Enough of an LRC's timings to compare it with another: when the first
	// and last sung lines start, and whether lines pile up on one stamp,
	// which hand-made uploads that went wrong tend to do.
	function shape(lrc: string): var {
		const times = [];
		const re = /^\[(\d+):(\d+(?:\.\d+)?)\][^\S\n]*\S/gm;
		let m;
		while ((m = re.exec(lrc)) !== null) times.push(Number(m[1]) * 60 + Number(m[2]));
		if (times.length < 2) return null;
		times.sort((a, b) => a - b);
		let stacked = 0;
		for (let i = 1; i < times.length; i++) if (times[i] - times[i - 1] < 0.01) stacked++;
		return { first: times[0], last: times[times.length - 1], stacked: stacked > 0 };
	}

	Timer {
		id: retry

		interval: 30000
		onTriggered: if (root.status === "error" && root.shown) root.load(false)
	}

	Component {
		id: request

		Process {
			id: proc

			property var handle

			running: true

			stdout: StdioCollector {
				onStreamFinished: proc.handle(text)
			}

			onExited: proc.destroy(1000)
		}
	}

	// ---- tidying what players report ----
	//
	// Spotify sends clean metadata. YouTube sends whatever the uploader typed:
	// "Artist - Song (Official Video) [4K]" from a channel called "ArtistVEVO",
	// or "Song | Artist | Film" from a label's channel.

	function cleanArtist(name: string): string {
		return (name ?? "")
			.replace(/\s*-\s*Topic$/i, "")
			.replace(/VEVO$/, "")
			.replace(/\s+(official|music)$/i, "")
			.trim();
	}

	function cleanTitle(name: string): string {
		const noise = "official|video|audio|lyric|visuali[sz]er|music|hd|hq|4k|mv|m/v|full song|remaster|explicit"
			+ "|clean|version|from|feat|ft\\b|prod|teaser|trailer|out now|color coded|letra|slowed|reverb|sped";
		return (name ?? "")
			.replace(new RegExp("\\s*[\\(\\[\\{【][^\\)\\]\\}】]*(" + noise + ")[^\\)\\]\\}】]*[\\)\\]\\}】]", "gi"), "")
			.replace(/\s*\[[^\]]*\]/g, "")
			.replace(/\s*\(\s*(ft|feat|featuring|with)\b[^)]*\)/gi, "")
			.replace(/^(full song|full video|video song|lyrical|lyric video|lyrics)\s*[:\-–]\s*/i, "")
			.split(/\s+[|｜]\s*|\s+\/\/\s+/)[0]
			.replace(/\s+(ft\.?|feat\.?|featuring)\s.*$/i, "")
			.replace(/\s+[-–—]\s+[^-–—]*\b(remaster(ed)?|live|edit|version|mix|mono|stereo|from|bonus|demo|acoustic|official|video|audio|lyrics?)\b.*$/i, "")
			.replace(/["“”]/g, "")
			.replace(/\s+/g, " ")
			.trim();
	}

	// (track, artist) pairs to try, most likely first.
	function candidates(title: string, artist: string): var {
		const track = root.cleanTitle(title);
		const who = root.cleanArtist(artist);
		const out = [];
		const add = (t, a) => {
			if (t && !out.some(c => c.track === t && c.artist === a)) out.push({ track: t, artist: a });
		};

		const parts = track.split(/\s+[-–—]\s+/);
		if (parts.length === 2) {
			// "Artist - Song", unless the channel's name is on the right.
			if (root.similar(parts[1], who)) add(parts[0], who);
			else add(parts[1], parts[0]);
		}
		add(track, who);

		// "A, B & C" is often filed under A alone.
		const first = who.split(/\s*(,|&| x | and )\s*/i)[0];
		if (first !== who) add(out[0]?.track ?? track, first);

		return out;
	}

	// Strict enough to tell "Rap God" from "God", loose enough to let
	// "Song (Remastered)" or "Song - From the film" through.
	function sameTitle(found: string, want: string): bool {
		const x = root.norm(root.cleanTitle(found));
		const y = root.norm(want);
		if (x === "" || y === "") return false;
		if (x === y) return true;
		const [short, long] = x.length < y.length ? [x, y] : [y, x];
		return long.startsWith(short) && short.length >= long.length * 0.6;
	}

	function norm(s: string): string {
		return (s ?? "").toLowerCase().replace(/[\s.,'’"!?()\[\]\-–—_:;&/]/g, "");
	}

	function similar(a: string, b: string): bool {
		const norm = s => (s ?? "").toLowerCase().replace(/[\s.,'’"!?()\[\]\-–—_:;&/]/g, "");
		const x = norm(a);
		const y = norm(b);
		return x !== "" && y !== "" && (x.includes(y) || y.includes(x));
	}

	// ---- LRC ----

	function parse(lrc: string): var {
		const out = [];
		let shift = 0;
		for (const raw of lrc.split(/\r?\n/)) {
			const tag = raw.match(/^\[offset:\s*([+-]?\d+)\s*\]/i);
			if (tag) { shift = Number(tag[1]) / 1000; continue; }

			const times = [];
			let rest = raw;
			let m;
			while ((m = rest.match(/^\[(\d+):(\d+(?:[.:]\d+)?)\]/))) {
				times.push(Number(m[1]) * 60 + Number(m[2].replace(":", ".")));
				rest = rest.slice(m[0].length);
			}
			// Word-level timings, which some entries carry, are not used.
			const text = rest.replace(/<\d+:\d+(?:\.\d+)?>/g, "").trim();
			for (const t of times) out.push({ time: Math.max(0, t - shift), text: text });
		}
		out.sort((a, b) => a.time - b.time);

		const lines = [];
		for (const line of out) {
			const text = line.text || "♪";
			if (text === "♪" && lines.length && lines[lines.length - 1].text === "♪") continue;
			lines.push({ time: line.time, text: text });
		}
		// Something to sit on through the intro.
		if (lines.length && lines[0].time > 1.5 && lines[0].text !== "♪") lines.unshift({ time: 0, text: "♪" });
		return lines;
	}

	// ---- cache ----
	//
	// One JSON file of { key: entry }, read on first use. Kept to the most
	// recent few hundred songs, which is well under a megabyte.

	readonly property int cacheLimit: 400
	readonly property int cacheVersion: 4
	readonly property real missLife: 3 * 24 * 3600 * 1000

	property var entries

	function cached(key: string): var {
		if (root.entries === undefined) {
			try {
				const parsed = JSON.parse(cache.text().trim() || "{}");
				root.entries = (parsed && typeof parsed === "object") ? parsed : ({});
			} catch (err) {
				root.entries = ({});
			}
		}
		return root.entries[key] ?? null;
	}

	function remember(key: string, entry) {
		root.cached(key);
		root.entries[key] = entry;

		const keys = Object.keys(root.entries);
		if (keys.length > root.cacheLimit) {
			keys.sort((a, b) => root.entries[a].at - root.entries[b].at);
			for (const old of keys.slice(0, keys.length - root.cacheLimit)) delete root.entries[old];
		}
		cache.setText(JSON.stringify(root.entries));
	}

	FileView {
		id: cache

		path: Quickshell.cachePath("lyrics.json")
		blockLoading: true
		printErrors: false
	}

	// ---- timing by hand ----
	//
	// For songs lrclib only has untimed lyrics for (or bad timings): play the
	// song and tap as each line starts. The result is kept in the state
	// directory rather than the cache, since it is work that cannot be
	// fetched again, and is used in preference to lrclib from then on.

	property bool timing: false

	// The screen whose overlay takes the keyboard while timing.
	property string timingScreen: ""

	// The line to tap next, and the times tapped so far.
	property int tapIndex: 0
	property var taps: []

	// Taps land a little after the line starts; this much is taken off.
	readonly property real reaction: 0.2

	function startTiming(screen: string) {
		if (root.timing || root.key === "" || root.lines.length === 0) return;
		const text = root.lines.map(l => l.text).filter(t => t !== "" && t !== "♪");
		if (text.length === 0) return;

		root.timingScreen = screen || (Quickshell.screens[0]?.name ?? "");
		root.taps = [];
		root.tapIndex = 0;
		root.lines = text.map(t => ({ time: -1, text: t }));
		root.index = 0;
		root.timing = true;

		// From the top, so the first line is not missed.
		if (root.player?.canSeek) root.player.position = 0;
		if (root.player && !root.player.isPlaying && root.player.canPlay) root.player.play();
	}

	function playhead(): real {
		return root.player?.positionSupported ? root.player.position : 0;
	}

	function tap() {
		if (!root.timing) return;
		const last = root.taps.length ? root.taps[root.taps.length - 1] : 0;
		const at = Math.max(last + 0.05, root.playhead() - root.reaction);
		root.taps = root.taps.concat([at]);
		root.tapIndex = root.taps.length;
		if (root.tapIndex >= root.lines.length) root.finishTiming();
		else root.index = root.tapIndex;
	}

	// Takes back the last tap and goes back to just before it, so the line
	// can be tapped again when it comes round.
	function untap() {
		if (!root.timing || root.taps.length === 0) return;
		const back = root.taps[root.taps.length - 1];
		root.taps = root.taps.slice(0, -1);
		root.tapIndex = root.taps.length;
		root.index = root.tapIndex;
		if (root.player?.canSeek) root.player.position = Math.max(0, back - 3);
	}

	function cancelTiming() {
		if (!root.timing) return;
		root.timing = false;
		root.taps = [];
		root.tapIndex = 0;
		root.load(false);
	}

	function finishTiming() {
		const stamp = t => {
			const cs = Math.round(t * 100);
			return "[" + String(Math.floor(cs / 6000)).padStart(2, "0") + ":"
				+ String(Math.floor(cs / 100) % 60).padStart(2, "0") + "."
				+ String(cs % 100).padStart(2, "0") + "]";
		};
		const lrc = root.lines.map((l, i) => stamp(root.taps[i]) + l.text).join("\n");
		const entry = {
			at: Date.now(),
			status: "found",
			source: "tapped",
			synced: lrc,
			plain: "",
			matched: root.matched || ((root.cleanArtist(root.artist) || "?") + " — " + root.cleanTitle(root.title)),
			length: root.length,
			offset: 0
		};
		root.keep(root.key, entry);
		root.timing = false;
		root.taps = [];
		root.tapIndex = 0;
		root.load(false);
	}

	// Drops hand timings for this song, back to whatever lrclib has.
	function forgetTiming() {
		if (!root.tapped(root.key)) return;
		root.cancelTiming();
		delete root.mine[root.key];
		timedStore.setText(JSON.stringify(root.mine));
		root.load(false);
	}

	property var mine

	function tapped(key: string): var {
		if (root.mine === undefined) {
			try {
				const parsed = JSON.parse(timedStore.text().trim() || "{}");
				root.mine = (parsed && typeof parsed === "object") ? parsed : ({});
			} catch (err) {
				root.mine = ({});
			}
		}
		return root.mine[key] ?? null;
	}

	function keep(key: string, entry) {
		root.tapped(key);
		root.mine[key] = entry;
		timedStore.setText(JSON.stringify(root.mine));
	}

	FileView {
		id: timedStore

		path: Quickshell.statePath("lyrics-timed.json")
		blockLoading: true
		printErrors: false
	}

	IpcHandler {
		target: "lyrics"

		function toggle(): void { root.toggle(); }
		function on(): void { if (!root.shown) root.toggle(); }
		function off(): void { if (root.shown) root.toggle(); }

		// Ignores the cache (and any hand timings, without deleting them)
		// and asks lrclib again.
		function refetch(): void { root.load(true); }

		// Timing by hand: start, tap each line, take one back, give up, or
		// throw away saved timings for this song.
		function time(): void { root.startTiming(""); }
		function tap(): void { root.tap(); }
		function untap(): void { root.untap(); }
		function cancel(): void { root.cancelTiming(); }
		function forget(): void { root.forgetTiming(); }

		// For lyrics that trail the singer, and for ones that run ahead.
		function sooner(): void { root.nudge(0.25); }
		function delay(): void { root.nudge(-0.25); }

		function state(): string {
			if (root.timing) return "timing · " + root.tapIndex + "/" + root.lines.length + " tapped";
			return root.status
				+ (root.source ? " (" + root.source + ")" : "")
				+ (root.matched ? " · " + root.matched : "")
				+ (root.searchedLength >= 0 ? " · for " + Math.round(root.searchedLength) + "s" : "")
				+ " · line " + root.index + "/" + root.lines.length
				+ (root.offset ? " · offset " + root.offset + "s" : "");
		}
	}
}
