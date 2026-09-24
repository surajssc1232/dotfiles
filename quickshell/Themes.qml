pragma Singleton

import QtQuick
import Quickshell

// Every palette the bar can wear. Add an entry here and it shows up in the
// theme menu automatically — nothing else needs to change.
Singleton {
	id: root

	readonly property var list: [
		{
			id: "gruvbox",
			name: "Gruvbox Dark",
			dark: true,
			bg: "#282828", bgAlt: "#3c3836", border: "#504945",
			fg: "#ebdbb2", fgDim: "#928374", accent: "#fe8019",
			green: "#b8bb26", yellow: "#fabd2f", red: "#fb4934", blue: "#83a598"
		},
		{
			id: "catppuccin-mocha",
			name: "Catppuccin Mocha",
			dark: true,
			bg: "#1e1e2e", bgAlt: "#313244", border: "#45475a",
			fg: "#cdd6f4", fgDim: "#6c7086", accent: "#cba6f7",
			green: "#a6e3a1", yellow: "#f9e2af", red: "#f38ba8", blue: "#89b4fa"
		},
		{
			id: "catppuccin-latte",
			name: "Catppuccin Latte",
			dark: false,
			bg: "#eff1f5", bgAlt: "#ccd0da", border: "#bcc0cc",
			fg: "#4c4f69", fgDim: "#8c8fa1", accent: "#8839ef",
			green: "#40a02b", yellow: "#df8e1d", red: "#d20f39", blue: "#1e66f5"
		},
		{
			id: "nord",
			name: "Nord",
			dark: true,
			bg: "#2e3440", bgAlt: "#3b4252", border: "#4c566a",
			fg: "#eceff4", fgDim: "#7b88a1", accent: "#88c0d0",
			green: "#a3be8c", yellow: "#ebcb8b", red: "#bf616a", blue: "#81a1c1"
		},
		{
			id: "tokyo-night",
			name: "Tokyo Night",
			dark: true,
			bg: "#1a1b26", bgAlt: "#24283b", border: "#414868",
			fg: "#c0caf5", fgDim: "#565f89", accent: "#7aa2f7",
			green: "#9ece6a", yellow: "#e0af68", red: "#f7768e", blue: "#7dcfff"
		},
		{
			id: "dracula",
			name: "Dracula",
			dark: true,
			bg: "#282a36", bgAlt: "#44475a", border: "#6272a4",
			fg: "#f8f8f2", fgDim: "#6272a4", accent: "#bd93f9",
			green: "#50fa7b", yellow: "#f1fa8c", red: "#ff5555", blue: "#8be9fd"
		},
		{
			id: "everforest",
			name: "Everforest Dark",
			dark: true,
			bg: "#2d353b", bgAlt: "#343f44", border: "#475258",
			fg: "#d3c6aa", fgDim: "#859289", accent: "#a7c080",
			green: "#a7c080", yellow: "#dbbc7f", red: "#e67e80", blue: "#7fbbb3"
		},
		{
			id: "rose-pine",
			name: "Rosé Pine",
			dark: true,
			bg: "#191724", bgAlt: "#26233a", border: "#403d52",
			fg: "#e0def4", fgDim: "#6e6a86", accent: "#c4a7e7",
			green: "#9ccfd8", yellow: "#f6c177", red: "#eb6f92", blue: "#31748f"
		},
		{
			id: "solarized",
			name: "Solarized Dark",
			dark: true,
			bg: "#002b36", bgAlt: "#073642", border: "#094959",
			fg: "#93a1a1", fgDim: "#586e75", accent: "#268bd2",
			green: "#859900", yellow: "#b58900", red: "#dc322f", blue: "#2aa198"
		},
		{
			id: "kanagawa",
			name: "Kanagawa",
			dark: true,
			bg: "#1f1f28", bgAlt: "#2a2a37", border: "#363646",
			fg: "#dcd7ba", fgDim: "#727169", accent: "#7e9cd8",
			green: "#98bb6c", yellow: "#e6c384", red: "#e46876", blue: "#7fb4ca"
		},
		{
			id: "mono",
			name: "Monochrome",
			dark: true,
			bg: "#000000", bgAlt: "#101010", border: "#333333",
			fg: "#ffffff", fgDim: "#8a8a8a", accent: "#ffffff",
			green: "#ffffff", yellow: "#cccccc", red: "#ffffff", blue: "#cccccc"
		}
	]

	readonly property string fallbackId: "gruvbox"

	// Unknown ids (a hand-edited state file, a theme that was removed) fall
	// back rather than leaving the bar with no palette at all.
	function get(id: string): var {
		return list.find(t => t.id === id) ?? list.find(t => t.id === fallbackId);
	}
}
