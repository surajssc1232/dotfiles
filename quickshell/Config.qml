pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
	id: root

	// ---- theme ----
	// Selected in the bar's theme menu; see Themes.qml for the palettes.
	property string themeId: Themes.fallbackId
	readonly property var theme: Themes.get(themeId)

	function setTheme(id: string) {
		if (root.themeId === id) return;
		root.themeId = id;
		stateFile.setText(id);
		root.applyExternal();
	}

	// Renders the palette into foot and neovim and reloads them.
	function applyExternal() {
		const t = root.theme;
		applyProc.command = [Quickshell.shellPath("scripts/apply-theme.sh"),
			t.bg, t.bgAlt, t.border, t.fg, t.fgDim, t.accent, t.green, t.yellow, t.red, t.blue];
		applyProc.running = true;
	}

	Process { id: applyProc }

	// Remembers the choice across restarts. Read synchronously at startup so
	// the bar's first frame is already drawn in the saved theme.
	FileView {
		id: stateFile

		path: Quickshell.statePath("theme")
		blockLoading: true
		printErrors: false
	}

	// ---- distro ----
	// Read from /etc/os-release so the settings button wears the logo of
	// whatever this is actually running on.
	property string distroId: "linux"
	property string distroName: "Linux"
	readonly property string distroIcon: icons.distro[distroId] ?? icons.distro["linux"]

	FileView {
		id: osRelease

		path: "/etc/os-release"
		blockLoading: true
		printErrors: false
	}

	Component.onCompleted: {
		const saved = stateFile.text().trim();
		if (saved) root.themeId = saved;
		root.applyExternal();

		// Values may be quoted, and ID_LIKE gives a usable fallback for the
		// many derivatives that have no logo of their own.
		const fields = ({});
		for (const line of osRelease.text().split("\n")) {
			const m = line.match(/^([A-Z_]+)=(.*)$/);
			if (m) fields[m[1]] = m[2].replace(/^"(.*)"$/, "$1").trim();
		}

		const like = (fields["ID_LIKE"] ?? "").split(/\s+/).find(id => icons.distro[id]);
		root.distroId = icons.distro[fields["ID"]] ? fields["ID"] : (like ?? "linux");
		root.distroName = fields["PRETTY_NAME"] || fields["NAME"] || "Linux";
	}

	// ---- colors ----
	// Raw palette. bg doubles as the ink on anything filled with accent, so it
	// stays exactly as the theme gives it.
	readonly property color bg: theme.bg
	readonly property color fg: theme.fg
	readonly property color accent: theme.accent
	readonly property color green: theme.green
	readonly property color yellow: theme.yellow
	readonly property color red: theme.red
	readonly property color blue: theme.blue

	// Tonal surfaces mixed out of the palette rather than taken from it, so
	// every widget in every theme steps through the same three levels without
	// each theme having to define them: a panel holds groups, a group holds
	// tiles. The terminal and neovim still get the theme's own values, since
	// applyExternal reads those from `theme` directly.
	readonly property color surface: Qt.tint(bg, Qt.alpha(accent, 0.05))
	readonly property color surfaceGroup: Qt.tint(bg, Qt.alpha(accent, 0.10))
	readonly property color bgAlt: Qt.tint(bg, Qt.alpha(accent, 0.18))
	readonly property color border: Qt.tint(bg, Qt.alpha(fg, 0.12))
	// Several themes' own fgDim is too faint for small text on a tinted surface.
	readonly property color fgDim: Qt.tint(theme.fgDim, Qt.alpha(fg, 0.5))

	// Hover on a tile, whatever its colour: Qt.lighter does nothing useful on
	// a light theme, where the surface is already near white.
	function hover(base: color): color {
		return Qt.tint(base, Qt.alpha(root.fg, 0.08));
	}

	// ---- bar geometry ----
	readonly property int barHeight: 34
	readonly property int barMargin: 6       // gap around the bar; 0 = docked
	readonly property int radius: 10

	// mango's outer gap (gappov/gappoh in ~/.config/mango/config.conf). The
	// compositor adds this below the bar's exclusive zone on its own, so the
	// zone is shrunk by it — otherwise the two gaps stack. Set barMargin to
	// this same value to line the bar's edges up with the window edges.
	readonly property int compositorGap: 10
	readonly property int spacing: 6
	readonly property int padding: 10
	// Between a panel's edge and what is on it: enough to clear radius.
	readonly property int inset: 12

	// How far past 100% a deliberate volume control may push the output.
	readonly property real volumeMax: 1.5

	// ---- fonts ----
	readonly property string font: "JetBrainsMono Nerd Font"
	readonly property int fontSize: 13

	// ---- behaviour ----
	readonly property string clockFormat: "hh:mm"
	readonly property string dateFormat: "ddd d MMM"
	readonly property int themeFade: 220      // ms, theme cross-fade duration
	readonly property int animFast: 140       // ms, hover and press feedback
	readonly property int animMed: 240        // ms, panels resizing and panes opening

	// Terminal used for the launcher's "run in terminal" entry, as an argv
	// prefix: whatever follows is appended as further arguments.
	readonly property var terminal: ["foot"]

	// The screenshot overlay in modules/ScreenshotOverlay.qml. Off because niri
	// takes screenshots itself and has Print bound to its own. With this false
	// nothing can start a capture — the keybind scripts, the launcher's
	// commands and the IPC calls all go quiet — and the launcher stops
	// offering them.
	readonly property bool screenshot: false

	// The Alt-Tab overlay in modules/Switcher.qml. Off because niri has a
	// window switcher of its own and two of them fighting over the same key is
	// worse than either — set this true to bring ours back, and nothing else
	// needs to change.
	readonly property bool switcher: false

	// Clipboard history. Everything copied as text is kept in the shell's own
	// state directory, so turning this off is also how you stop it reaching
	// disk at all — the watcher itself does not run.
	readonly property bool clipboardHistory: true
	readonly property int clipboardLimit: 200

	// Images are kept as files under the cache directory. Fewer of them than
	// text entries, because each one is a screenshot-sized file.
	// A notification with a thumbnail whenever an image is copied — which on
	// this system means whenever a screenshot is taken, since niri puts them
	// straight on the clipboard. With this on, niri's own plain "Screenshot
	// captured" is suppressed so there is one notification rather than two.
	readonly property bool screenshotPreview: true

	readonly property bool clipboardImages: true
	readonly property int clipboardImageLimit: 20

	// How often the wallpaper slideshow moves on, in minutes.
	readonly property int slideshowMinutes: 15

	// Where the wallpaper picker looks for images.
	readonly property string wallpaperDir: Quickshell.env("HOME") + "/Downloads"

	// Weather. One of the two parts of this shell that make network requests;
	// the other is lyrics, below.
	//
	// Leave the coordinates at 0 and the location is looked up once from your
	// IP address (through ipapi.co) and cached; set them and nothing but
	// open-meteo is ever contacted. Set weather to false and neither happens.
	readonly property bool weather: true
	readonly property real weatherLatitude: 0
	readonly property real weatherLongitude: 0

	// Timed lyrics for whatever is playing, from lrclib.net. While the overlay
	// is shown (Mod+Alt+Y), each new track's title and artist are sent there
	// once and the answer cached. Set false and nothing is ever requested.
	readonly property bool lyrics: true

	// Night light. Lower is warmer; 6500 is neutral daylight. nightTemp is only
	// the starting point: once it has been stepped from the control centre, that
	// value is remembered instead. The range must stay below dayTemp, as wlsunset
	// refuses a low temperature that is not below the high one.
	readonly property int nightTemp: 4000
	readonly property int nightTempMin: 2000
	readonly property int nightTempMax: 6000
	readonly property int nightTempStep: 200
	readonly property int dayTemp: 6500

	// ---- icons (Nerd Font, escaped so the source stays plain ASCII) ----
	readonly property var icons: ({
		logo: "\uf17c",        // linux
		calendar: "\uf073",
		cpu: "\uf2db",         // microchip
		ram: "\uf1c0",         // database
		disk: "\uf0a0",        // hdd
		volHigh: "\uf028",
		volLow: "\uf027",
		volMute: "\uf026",
		mic: "\uf130",
		micOff: "\uf131",
		charging: "\uf0e7",    // bolt
		battery: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
		palette: "\uf1fc",     // paint brush
		chevron: "\uf078",
		chevronLeft: "\uf053",
		chevronRight: "\uf054",
		today: "\uf05b",       // crosshairs
		settings: "\uf013",    // cog
		bell: "\uf0f3",
		bellOff: "\uf1f6",
		broom: "\uf51a",
		inbox: "\uf01c",
		toggleOn: "\uf205",
		toggleOff: "\uf204",
		kill: "\uf00d",
		sort: "\uf0dd",
		check: "\uf00c",
		swatch: "\uf111",      // filled circle
		wifi: "\uf1eb",
		wifiOff: "\uf127",     // chain-broken
		lock: "\uf023",
		refresh: "\uf021",
		trash: "\uf1f8",
		key: "\uf084",
		spinner: "\uf110",
		warning: "\uf071",
		disconnect: "\uf057",  // times-circle
		bluetooth: "\uf293",
		// Keyed by os-release ID; codepoints verified against the
		// font's cmap (the Font Logos block, nf-linux-*).
		distro: ({
			"nixos": "\uf313", "arch": "\uf303", "artix": "\uf31f",
			"archcraft": "\uf345", "arcolinux": "\uf346",
			"endeavouros": "\uf322", "manjaro": "\uf312", "garuda": "\uf337",
			"ubuntu": "\uf31b", "kubuntu": "\uf333", "debian": "\uf306",
			"devuan": "\uf307", "linuxmint": "\uf30e", "pop": "\uf32a",
			"elementary": "\uf309", "zorin": "\uf32f", "kali": "\uf327",
			"parrot": "\uf329", "raspbian": "\uf315", "mx": "\uf33f",
			"fedora": "\uf30a", "rhel": "\uf316", "centos": "\uf304",
			"almalinux": "\uf31d", "rocky": "\uf32b", "opensuse": "\uf314",
			"opensuse-tumbleweed": "\uf314", "opensuse-leap": "\uf314",
			"suse": "\uf314", "gentoo": "\uf30d", "alpine": "\uf300",
			"void": "\uf32e", "solus": "\uf32d", "mageia": "\uf310",
			"slackware": "\uf318", "qubes": "\uf342", "guix": "\uf325",
			"deepin": "\uf321", "tails": "\uf343", "neon": "\uf331",
			"freebsd": "\uf30c", "openbsd": "\uf328", "darwin": "\uf302",
			"linux": "\uf31a"
		}),
		down: "\uf063",
		brightness: "\uf185",   // sun
		nightLight: "\uf186",   // moon
		camera: "\uf030",
		image: "\uf03e",
		record: "\uf111",     // filled circle
		video: "\uf03d",
		stop: "\uf04d",
		clipboard: "\uf0ea",
		crop: "\uf125",
		display: "\uf108",
		plug: "\uf1e6",
		power: "\uf011",       // power-off
		clockFace: "\uf252",   // hourglass
		up: "\uf062",
		search: "\uf002",
		user: "\uf007",
		arrowRight: "\uf061",
		apps: "\uf00a",        // grid
		terminal: "\uf120",
		calculator: "\uf1ec",
		window: "\uf2d0",      // window-maximize
		keyboard: "\uf11c",
		play: "\uf04b",
		pause: "\uf04c",
		next: "\uf051",
		prev: "\uf048",
		music: "\uf001",
		lyrics: "\uf130",
		mixer: "\uf1de",       // sliders
		pin: "\uf08d",
		timer: "\uf017",       // clock
		emoji: "\uf118",       // smile
		cloud: "\uf0c2",
		wind: "\ue34b",        // nf-weather-strong_wind
		leaf: "\uf06c",        // air quality
		plus: "\uf067",
		minus: "\uf068",
		close: "\uf00d",
		meeting: "\uf0c0",     // users
		repeat: "\uf01e",
		history: "\uf1da",
		question: "\uf059",
		rocket: "\uf135",
		enter: "\uf090",       // sign-in
		// Plain arrows for the launcher's key hints; the Nerd Font ones above
		// are icon-weight and read as glyphs rather than as keys.
		keyUp: "\u2191",
		keyDown: "\u2193",
		dot: "\u00b7",
		// Freedesktop icon names reported by BlueZ, mapped onto the font.
		device: ({
			"audio-headset": "\uf025",
			"audio-headphones": "\uf025",
			"audio-card": "\uf028",
			"audio-speakers": "\uf028",
			"input-keyboard": "\uf11c",
			"input-mouse": "\uf245",
			"input-tablet": "\uf10b",
			"input-gaming": "\uf11b",
			"phone": "\uf10b",
			"computer": "\uf109",
			"video-display": "\uf26c",
			"printer": "\uf02f",
			"camera-photo": "\uf030",
			"camera-video": "\uf030",
			"unknown": "\uf294"
		})
	})
}
