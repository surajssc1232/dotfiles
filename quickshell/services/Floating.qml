pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Applications that open as floating windows instead of tiled ones, chosen
// from the launcher (right-click an app → Always open floating).
//
// niri decides this itself, from window rules, so this only writes them: one
// rule into ~/.config/niri/quickshell-floating.kdl, which config.kdl includes.
// niri watches included files too, so a change applies the moment the file is
// saved — no reload, and the rules keep working with the shell not running.
// Windows of the app that are already open are floated (or tiled) straight
// away as well, so the choice shows immediately rather than on the next launch.
Singleton {
	id: root

	// Desktop entry ids, in the order they were chosen.
	property var apps: []

	readonly property string rulesPath: Quickshell.env("HOME") + "/.config/niri/quickshell-floating.kdl"

	function has(id: string): bool { return root.apps.indexOf(id) !== -1; }

	function setFloating(id: string, on: bool) {
		if (!id || root.has(id) === on) return;
		root.apps = on ? root.apps.concat([id]) : root.apps.filter(a => a !== id);
		Persist.set("floatingApps", root.apps);
		root.write();
		root.applyOpen(id, on);
	}

	function toggle(id: string) { root.setFloating(id, !root.has(id)); }

	// What a window of this app reports as its app id. Usually the desktop
	// entry's own id (org.qbittorrent.qBittorrent, foot); X11 and some Electron
	// apps report their StartupWMClass instead. Both are matched, ignoring case.
	function names(id: string): var {
		const out = [id];
		const e = DesktopEntries.byId(id);
		if (e?.startupClass && out.indexOf(e.startupClass) === -1) out.push(e.startupClass);
		// Entries named reverse-DNS style often run as their last part alone.
		const tail = id.split(".").pop();
		if (tail !== id && out.indexOf(tail) === -1) out.push(tail);
		return out;
	}

	function quote(s: string): string {
		return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	}

	function pattern(id: string): string {
		return "(?i)^(" + root.names(id).map(n => root.quote(n)).join("|") + ")$";
	}

	function matches(id: string, appId: string): bool {
		if (!appId) return false;
		const a = appId.toLowerCase();
		return root.names(id).some(n => n.toLowerCase() === a);
	}

	function write() {
		let text = "// Written by quickshell (services/Floating.qml): apps chosen to open\n"
			+ "// floating from the launcher. Edits here are overwritten; use the\n"
			+ "// launcher's right-click menu instead.\n";
		if (root.apps.length > 0) {
			text += "\nwindow-rule {\n";
			for (const id of root.apps) text += '    match app-id=r#"' + root.pattern(id) + '"#\n';
			text += "    open-floating true\n}\n";
		}
		rules.setText(text);
	}

	// The app's windows that are open now, moved to match the new choice.
	function applyOpen(id: string, on: bool) {
		for (const w of Niri.windows) {
			if (!root.matches(id, w.app_id) || (w.is_floating ?? false) === on) continue;
			Quickshell.execDetached({ command: ["niri", "msg", "action",
				on ? "move-window-to-floating" : "move-window-to-tiling", "--id", String(w.id)] });
		}
	}

	FileView {
		id: rules

		path: root.rulesPath
		printErrors: false
		atomicWrites: true
	}

	Component.onCompleted: {
		const saved = Persist.get("floatingApps", []);
		root.apps = Array.isArray(saved) ? saved : [];
		// Rewritten at startup so the file always exists for config.kdl's
		// include — niri refuses a config whose include is missing.
		root.write();
	}

	IpcHandler {
		target: "floating"

		function toggle(id: string): void { root.toggle(id); }
		function add(id: string): void { root.setFloating(id, true); }
		function remove(id: string): void { root.setFloating(id, false); }
		function list(): string { return root.apps.join("\n"); }
	}
}
