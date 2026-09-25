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
		},
		{
			id: "gruvbox-light",
			name: "Gruvbox Light",
			dark: false,
			bg: "#fbf1c7", bgAlt: "#ebdbb2", border: "#d5c4a1",
			fg: "#3c3836", fgDim: "#7c6f64", accent: "#af3a03",
			green: "#79740e", yellow: "#b57614", red: "#9d0006", blue: "#076678"
		},
		{
			id: "solarized-light",
			name: "Solarized Light",
			dark: false,
			bg: "#fdf6e3", bgAlt: "#eee8d5", border: "#d3cbb7",
			fg: "#586e75", fgDim: "#93a1a1", accent: "#268bd2",
			green: "#859900", yellow: "#b58900", red: "#dc322f", blue: "#2aa198"
		},
		{
			id: "tokyo-night-storm",
			name: "Tokyo Night Storm",
			dark: true,
			bg: "#24283b", bgAlt: "#2f334d", border: "#414868",
			fg: "#c0caf5", fgDim: "#565f89", accent: "#7aa2f7",
			green: "#9ece6a", yellow: "#e0af68", red: "#f7768e", blue: "#7dcfff"
		},
		{
			id: "tokyo-night-day",
			name: "Tokyo Night Day",
			dark: false,
			bg: "#e1e2e7", bgAlt: "#d2d4de", border: "#c4c8da",
			fg: "#3760bf", fgDim: "#848cb5", accent: "#2e7de9",
			green: "#587539", yellow: "#8c6c3e", red: "#f52a65", blue: "#007197"
		},
		{
			id: "catppuccin-macchiato",
			name: "Catppuccin Macchiato",
			dark: true,
			bg: "#24273a", bgAlt: "#363a4f", border: "#494d64",
			fg: "#cad3f5", fgDim: "#6e738d", accent: "#c6a0f6",
			green: "#a6da95", yellow: "#eed49f", red: "#ed8796", blue: "#8aadf4"
		},
		{
			id: "catppuccin-frappe",
			name: "Catppuccin Frappé",
			dark: true,
			bg: "#303446", bgAlt: "#414559", border: "#51576d",
			fg: "#c6d0f5", fgDim: "#737994", accent: "#ca9ee6",
			green: "#a6d189", yellow: "#e5c890", red: "#e78284", blue: "#8caaee"
		},
		{
			id: "rose-pine-moon",
			name: "Rosé Pine Moon",
			dark: true,
			bg: "#232136", bgAlt: "#2a273f", border: "#44415a",
			fg: "#e0def4", fgDim: "#6e6a86", accent: "#c4a7e7",
			green: "#3e8fb0", yellow: "#f6c177", red: "#eb6f92", blue: "#9ccfd8"
		},
		{
			id: "rose-pine-dawn",
			name: "Rosé Pine Dawn",
			dark: false,
			bg: "#faf4ed", bgAlt: "#fffaf3", border: "#dfdad9",
			fg: "#575279", fgDim: "#9893a5", accent: "#907aa9",
			green: "#286983", yellow: "#ea9d34", red: "#b4637a", blue: "#56949f"
		},
		{
			id: "everforest-light",
			name: "Everforest Light",
			dark: false,
			bg: "#fdf6e3", bgAlt: "#f4f0d9", border: "#e0dcc7",
			fg: "#5c6a72", fgDim: "#939f91", accent: "#8da101",
			green: "#8da101", yellow: "#dfa000", red: "#f85552", blue: "#3a94c5"
		},
		{
			id: "nord-light",
			name: "Nord Light",
			dark: false,
			bg: "#eceff4", bgAlt: "#e5e9f0", border: "#d8dee9",
			fg: "#2e3440", fgDim: "#4c566a", accent: "#5e81ac",
			green: "#a3be8c", yellow: "#d08770", red: "#bf616a", blue: "#81a1c1"
		},
		{
			id: "one-dark",
			name: "One Dark",
			dark: true,
			bg: "#282c34", bgAlt: "#3e4451", border: "#4b5263",
			fg: "#abb2bf", fgDim: "#5c6370", accent: "#61afef",
			green: "#98c379", yellow: "#e5c07b", red: "#e06c75", blue: "#56b6c2"
		},
		{
			id: "one-light",
			name: "One Light",
			dark: false,
			bg: "#fafafa", bgAlt: "#eaeaeb", border: "#d4d4d5",
			fg: "#383a42", fgDim: "#a0a1a7", accent: "#4078f2",
			green: "#50a14f", yellow: "#c18401", red: "#e45649", blue: "#0184bc"
		},
		{
			id: "palenight",
			name: "Palenight",
			dark: true,
			bg: "#292d3e", bgAlt: "#32374d", border: "#444267",
			fg: "#a6accd", fgDim: "#676e95", accent: "#c792ea",
			green: "#c3e88d", yellow: "#ffcb6b", red: "#f07178", blue: "#82aaff"
		},
		{
			id: "ayu-dark",
			name: "Ayu Dark",
			dark: true,
			bg: "#0b0e14", bgAlt: "#131721", border: "#1f2430",
			fg: "#bfbdb6", fgDim: "#565b66", accent: "#ffb454",
			green: "#aad94c", yellow: "#e6b450", red: "#f26d78", blue: "#59c2ff"
		},
		{
			id: "ayu-mirage",
			name: "Ayu Mirage",
			dark: true,
			bg: "#1f2430", bgAlt: "#242936", border: "#343b4d",
			fg: "#cccac2", fgDim: "#707a8c", accent: "#ffcc66",
			green: "#bae67e", yellow: "#ffd580", red: "#f28779", blue: "#73d0ff"
		},
		{
			id: "nightfox",
			name: "Nightfox",
			dark: true,
			bg: "#192330", bgAlt: "#212e3f", border: "#29394f",
			fg: "#cdcecf", fgDim: "#71839b", accent: "#719cd6",
			green: "#81b29a", yellow: "#dbc074", red: "#c94f6d", blue: "#63cdcf"
		},
		{
			id: "oxocarbon",
			name: "Oxocarbon",
			dark: true,
			bg: "#161616", bgAlt: "#262626", border: "#393939",
			fg: "#f2f4f8", fgDim: "#6f6f6f", accent: "#be95ff",
			green: "#42be65", yellow: "#f1c21b", red: "#ee5396", blue: "#33b1ff"
		},
		{
			id: "melange-dark",
			name: "Melange Dark",
			dark: true,
			bg: "#292522", bgAlt: "#34302c", border: "#403a36",
			fg: "#ece1d7", fgDim: "#867462", accent: "#d47766",
			green: "#85b695", yellow: "#ebc06d", red: "#d47766", blue: "#a3a9ce"
		},
		{
			id: "zenburn",
			name: "Zenburn",
			dark: true,
			bg: "#3f3f3f", bgAlt: "#4f4f4f", border: "#6f6f6f",
			fg: "#dcdccc", fgDim: "#9f9f9f", accent: "#f0dfaf",
			green: "#7f9f7f", yellow: "#e3ceab", red: "#cc9393", blue: "#8cd0d3"
		},
		{
			id: "github-dark",
			name: "GitHub Dark",
			dark: true,
			bg: "#0d1117", bgAlt: "#161b22", border: "#30363d",
			fg: "#c9d1d9", fgDim: "#8b949e", accent: "#58a6ff",
			green: "#3fb950", yellow: "#d29922", red: "#f85149", blue: "#79c0ff"
		}
	]

	readonly property string fallbackId: "gruvbox"

	// Unknown ids (a hand-edited state file, a theme that was removed) fall
	// back rather than leaving the bar with no palette at all.
	function get(id: string): var {
		return list.find(t => t.id === id) ?? list.find(t => t.id === fallbackId);
	}
}
