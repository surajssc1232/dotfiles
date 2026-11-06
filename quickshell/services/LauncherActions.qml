pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.services

// The shell's own commands, as launcher entries.
//
// Everything here already exists as a service; this only gives it a name you
// can type. Kept out of Launcher.qml because that file is about ranking and
// this one is a list — and because adding a command should mean adding six
// lines here and nothing anywhere else.
//
// Entries are rebuilt whenever the state they describe changes, so a toggle
// reads "Night light on" or "Night light off" rather than always the same.
Singleton {
	id: root

	// Reachable from a plain search. These are all reversible.
	readonly property var everyday: [
		({
			id: "lock", name: "Lock screen", detail: "Ctrl+Alt+L",
			glyph: Config.icons.lock,
			run: () => Lock.lock()
		}),
		({
			id: "shot-region", name: "Screenshot a region", detail: "Super+Shift+S · Shift+Print",
			glyph: Config.icons.crop,
			run: () => root.niri("screenshot")
		}),
		({
			id: "shot-full", name: "Screenshot the screen", detail: "Super+Ctrl+S · Print",
			glyph: Config.icons.camera,
			run: () => root.niri("screenshot-screen")
		}),
		({
			id: "shot-window", name: "Screenshot a window", detail: "Super+Alt+S · Super+Print",
			glyph: Config.icons.camera,
			run: () => root.niri("screenshot-window")
		}),
		({
			id: "shot-delay", when: Config.screenshot, name: "Screenshot in 5 seconds", detail: "Super+Shift+Print",
			glyph: Config.icons.clockFace,
			run: () => Shot.start("full", 5000)
		}),
		({
			id: "record",
			name: Recorder.recording ? "Stop recording" : "Start recording",
			// The elapsed time is deliberately not baked in here. This array is
			// a binding, so reading a value that changes once a second would
			// rebuild every entry once a second — and with them the launcher's
			// model, which resets the list's scroll position out from under
			// anyone reading it. `liveClock` tells the delegate to read the
			// clock itself; see the detail Label in modules/Launcher.qml.
			detail: Recorder.recording ? "" : "Ctrl+Alt+R",
			liveClock: true,
			glyph: Recorder.recording ? Config.icons.stop : Config.icons.video,
			run: () => Recorder.recording ? Recorder.stop() : Recorder.start("")
		}),
		({
			id: "night",
			name: NightLight.enabled ? "Turn night light off" : "Turn night light on",
			detail: NightLight.temperature + "K",
			glyph: Config.icons.nightLight,
			run: () => NightLight.toggle()
		}),
		({
			id: "dnd",
			name: Notifs.dnd ? "Turn do not disturb off" : "Turn do not disturb on",
			detail: Notifs.dnd ? "Notifications are silenced" : "Silence notifications",
			glyph: Notifs.dnd ? Config.icons.bellOff : Config.icons.bell,
			run: () => Notifs.toggleDnd()
		}),
		({
			id: "clear-notifs", name: "Clear notifications",
			detail: Notifs.count + " in history",
			glyph: Config.icons.broom,
			run: () => Notifs.clearAll()
		}),
		({
			id: "wallpaper", name: "Random wallpaper",
			detail: Wallpaper.count + " in " + Config.wallpaperDir.replace(Quickshell.env("HOME"), "~"),
			glyph: Config.icons.image,
			run: () => root.randomWallpaper()
		}),
		({
			id: "slideshow",
			name: Wallpaper.slideshow ? "Stop wallpaper slideshow" : "Start wallpaper slideshow",
			detail: "Every " + Config.slideshowMinutes + " minutes",
			glyph: Config.icons.image,
			run: () => Wallpaper.toggleSlideshow()
		}),
		({
			id: "wifi",
			name: Network.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on",
			detail: Network.connected ? Network.activeSsid : "Not connected",
			glyph: Network.wifiEnabled ? Config.icons.wifi : Config.icons.wifiOff,
			run: () => Network.setWifiEnabled(!Network.wifiEnabled)
		}),
		({
			id: "clear-clipboard", name: "Clear clipboard history",
			detail: Clipboard.entries.length + " entries kept",
			glyph: Config.icons.clipboard,
			run: () => Clipboard.clear()
		}),
		({
			id: "storage", name: "Storage", detail: "Disk usage, junk and large files",
			glyph: Config.icons.disk,
			run: () => Storage.show()
		}),
		({
			id: "bt", when: Bt.available,
			name: Bt.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on",
			detail: Bt.blocked ? "Blocked by rfkill"
				: Bt.connectedDevices.length > 0
					? Bt.connectedDevices.map(d => Bt.label(d)).join(", ")
					: "Nothing connected · & lists devices",
			keywords: "bluetooth bt wireless",
			glyph: Config.icons.bluetooth,
			run: () => Bt.blocked ? Bt.unblock() : Bt.setEnabled(!Bt.enabled)
		}),
		({
			id: "mute", when: Audio.sink !== null,
			name: Audio.sink?.audio?.muted ? "Unmute sound" : "Mute sound",
			detail: Audio.label(Audio.sink),
			keywords: "audio volume speaker output silence",
			glyph: Audio.sink?.audio?.muted ? Config.icons.volMute : Config.icons.volHigh,
			run: () => { if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
		}),
		({
			id: "mic-mute", when: Audio.source !== null,
			name: Audio.source?.audio?.muted ? "Unmute microphone" : "Mute microphone",
			detail: Audio.label(Audio.source),
			keywords: "mic input record capture",
			glyph: Config.icons.mic,
			run: () => { if (Audio.source?.audio) Audio.source.audio.muted = !Audio.source.audio.muted; }
		}),
		({
			id: "lyrics", when: Lyrics.enabled,
			name: Lyrics.shown ? "Hide lyrics" : "Show lyrics",
			detail: Lyrics.title ? Lyrics.title + (Lyrics.artist ? " · " + Lyrics.artist : "") : "Nothing playing",
			keywords: "song music karaoke overlay",
			glyph: Config.icons.music,
			run: () => Lyrics.toggle()
		}),
		({
			id: "control-centre", name: "Control centre", detail: "Wi-Fi, Bluetooth, power, sliders",
			keywords: "settings quick panel toggles",
			glyph: Config.icons.settings,
			run: () => root.spawn(["quickshell", "ipc", "call", "settings", "toggle"])
		}),
		({
			id: "notif-centre", name: "Notification centre", detail: Notifs.count + " in history",
			keywords: "notifications history",
			glyph: Config.icons.bell,
			run: () => Notifs.centerToggled()
		}),
		({
			id: "clipboard", name: "Clipboard history", detail: "; searches it here too",
			keywords: "paste copied",
			glyph: Config.icons.clipboard,
			run: () => Clipboard.show()
		}),
		({
			id: "reload", name: "Reload the shell", detail: "Re-reads the config",
			glyph: Config.icons.refresh,
			run: () => Quickshell.reload(false)
		})
	]

	// One per palette, so a theme is two keystrokes away.
	readonly property var themes: Themes.list.map(t => ({
		id: "theme:" + t.id,
		name: "Theme: " + t.name,
		detail: Config.themeId === t.id ? "Current" : "",
		glyph: Config.themeId === t.id ? Config.icons.check : Config.icons.swatch,
		run: () => Config.setTheme(t.id)
	}))

	// One per power profile the daemon offers, the current one ticked.
	readonly property var powerModes: Power.available ? Power.profiles.map(id => ({
		id: "power:" + id,
		name: "Power mode: " + Power.title(id),
		detail: Power.profile === id ? "Current" : "",
		keywords: "power profile performance balanced saver battery",
		glyph: Power.profile === id ? Config.icons.check : Power.icon(id),
		run: () => Power.set(id)
	})) : []

	// Reachable from a plain search too, but only strictly: `strict` rows
	// match only when what you typed starts the name or one of its keywords
	// (three letters at least), never as a fuzzy scatter, so typing part of
	// an application's name cannot put "Power off" under the cursor. Anything
	// that ends the session also wants Enter twice (`confirm`).
	readonly property var session: [
		({
			id: "suspend", name: "Suspend", detail: "Sleep now",
			strict: true, keywords: "sleep",
			glyph: Config.icons.nightLight,
			run: () => root.spawn(["systemctl", "suspend"])
		}),
		({
			id: "logout", name: "Log out", detail: "Ends this session",
			strict: true, confirm: true, keywords: "logout sign out exit quit session",
			glyph: Config.icons.disconnect,
			run: () => root.spawn(["sh", "-c",
				'loginctl terminate-session "${XDG_SESSION_ID:-}" '
				+ '|| loginctl terminate-user "$USER"'])
		}),
		({
			id: "reboot", name: "Restart", detail: "Reboots the machine",
			strict: true, confirm: true, keywords: "reboot",
			glyph: Config.icons.refresh,
			run: () => root.spawn(["systemctl", "reboot"])
		}),
		({
			id: "poweroff", name: "Power off", detail: "Shuts the machine down",
			strict: true, confirm: true, keywords: "shutdown shut down turn off",
			glyph: Config.icons.plug,
			run: () => root.spawn(["systemctl", "poweroff"])
		}),
		({
			id: "firmware", name: "Restart into firmware setup", detail: "BIOS / UEFI settings",
			strict: true, confirm: true, keywords: "bios uefi firmware",
			glyph: Config.icons.refresh,
			run: () => root.spawn(["systemctl", "reboot", "--firmware-setup"])
		})
	]

	// `when: false` hides an entry without deleting it — the delayed
	// screenshot goes away with Config.screenshot, rather than sitting in the list
	// offering something that cannot happen.
	function enabled(list): var {
		return list.filter(a => a.when === undefined || a.when);
	}

	readonly property var all: root.enabled(root.everyday).concat(root.powerModes)
		.concat(root.themes).concat(root.enabled(root.session))
	// The ! mode lists the same things; kept as a name for its callers.
	readonly property var withSession: root.all

	function randomWallpaper() {
		const n = Wallpaper.count;
		if (n === 0) return;
		Wallpaper.set(Wallpaper.pathAt(Math.floor(Math.random() * n)));
	}

	// niri's own screenshots, the same ones the keybinds take, so they work
	// with the shell's capture (Config.screenshot) switched off.
	function niri(action) {
		root.spawn(["niri", "msg", "action", action]);
	}

	function spawn(argv) {
		Quickshell.execDetached({ command: argv });
	}
}
