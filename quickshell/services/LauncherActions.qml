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
			id: "shot-region", when: Config.screenshot, name: "Screenshot a region", detail: "Shift+Print",
			glyph: Config.icons.crop,
			run: () => Shot.start("region", 1)
		}),
		({
			id: "shot-full", when: Config.screenshot, name: "Screenshot the screen", detail: "Super+Print",
			glyph: Config.icons.camera,
			run: () => Shot.start("full", 1)
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

	// Deliberately absent from a plain search. Typing three letters of an
	// application's name should never put "Power off" under the cursor, so
	// these are reachable only through the ! prefix, where asking for them is
	// the whole point of what you typed.
	readonly property var session: [
		({
			id: "suspend", name: "Suspend", detail: "Sleep now",
			glyph: Config.icons.nightLight,
			run: () => root.spawn(["systemctl", "suspend"])
		}),
		({
			id: "logout", name: "Log out", detail: "Ends this session",
			glyph: Config.icons.disconnect,
			run: () => root.spawn(["sh", "-c",
				'loginctl terminate-session "${XDG_SESSION_ID:-}" '
				+ '|| loginctl terminate-user "$USER"'])
		}),
		({
			id: "reboot", name: "Restart", detail: "Reboots the machine",
			glyph: Config.icons.refresh,
			run: () => root.spawn(["systemctl", "reboot"])
		}),
		({
			id: "poweroff", name: "Power off", detail: "Shuts the machine down",
			glyph: Config.icons.plug,
			run: () => root.spawn(["systemctl", "poweroff"])
		})
	]

	// `when: false` hides an entry without deleting it — the screenshot
	// commands go away with Config.screenshot, rather than sitting in the list
	// offering something that cannot happen.
	function enabled(list): var {
		return list.filter(a => a.when === undefined || a.when);
	}

	readonly property var all: root.enabled(root.everyday).concat(root.themes)
	readonly property var withSession: root.all.concat(root.enabled(root.session))

	function randomWallpaper() {
		const n = Wallpaper.count;
		if (n === 0) return;
		Wallpaper.set(Wallpaper.pathAt(Math.floor(Math.random() * n)));
	}

	function spawn(argv) {
		Quickshell.execDetached({ command: argv });
	}
}
