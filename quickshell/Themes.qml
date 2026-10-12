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
		},
		{
			id: "monokai",
			name: "Monokai",
			dark: true,
			bg: "#272822", bgAlt: "#3e3d32", border: "#49483e",
			fg: "#f8f8f2", fgDim: "#75715e", accent: "#a6e22e",
			green: "#a6e22e", yellow: "#e6db74", red: "#f92672", blue: "#66d9ef"
		},
		{
			id: "monokai-pro",
			name: "Monokai Pro",
			dark: true,
			bg: "#2d2a2e", bgAlt: "#403e41", border: "#5b595c",
			fg: "#fcfcfa", fgDim: "#727072", accent: "#ffd866",
			green: "#a9dc76", yellow: "#ffd866", red: "#ff6188", blue: "#78dce8"
		},
		{
			id: "gruvbox-material",
			name: "Gruvbox Material",
			dark: true,
			bg: "#292828", bgAlt: "#32302f", border: "#45403d",
			fg: "#d4be98", fgDim: "#928374", accent: "#a9b665",
			green: "#a9b665", yellow: "#d8a657", red: "#ea6962", blue: "#7daea3"
		},
		{
			id: "gruvbox-material-light",
			name: "Gruvbox Material Light",
			dark: false,
			bg: "#fbf1c7", bgAlt: "#f2e5bc", border: "#e0d4a8",
			fg: "#654735", fgDim: "#928374", accent: "#6c782e",
			green: "#6c782e", yellow: "#b47109", red: "#c14a4a", blue: "#45707a"
		},
		{
			id: "material-ocean",
			name: "Material Ocean",
			dark: true,
			bg: "#0f111a", bgAlt: "#1a1c25", border: "#2b2f40",
			fg: "#8f93a2", fgDim: "#464b5d", accent: "#84ffff",
			green: "#c3e88d", yellow: "#ffcb6b", red: "#f07178", blue: "#82aaff"
		},
		{
			id: "material-darker",
			name: "Material Darker",
			dark: true,
			bg: "#212121", bgAlt: "#292929", border: "#424242",
			fg: "#eeffff", fgDim: "#545454", accent: "#82aaff",
			green: "#c3e88d", yellow: "#ffcb6b", red: "#f07178", blue: "#89ddff"
		},
		{
			id: "material-lighter",
			name: "Material Lighter",
			dark: false,
			bg: "#fafafa", bgAlt: "#eceff1", border: "#cfd8dc",
			fg: "#546e7a", fgDim: "#90a4ae", accent: "#6182b8",
			green: "#91b859", yellow: "#f6a434", red: "#e53935", blue: "#39adb5"
		},
		{
			id: "night-owl",
			name: "Night Owl",
			dark: true,
			bg: "#011627", bgAlt: "#0b2942", border: "#5f7e97",
			fg: "#d6deeb", fgDim: "#637777", accent: "#82aaff",
			green: "#addb67", yellow: "#ecc48d", red: "#ef5350", blue: "#7fdbca"
		},
		{
			id: "cobalt2",
			name: "Cobalt2",
			dark: true,
			bg: "#193549", bgAlt: "#1f4662", border: "#2d5b7e",
			fg: "#ffffff", fgDim: "#7aa6c0", accent: "#ffc600",
			green: "#3ad900", yellow: "#ffc600", red: "#ff628c", blue: "#0088ff"
		},
		{
			id: "synthwave-84",
			name: "Synthwave '84",
			dark: true,
			bg: "#262335", bgAlt: "#34294f", border: "#495495",
			fg: "#ffffff", fgDim: "#848bbd", accent: "#ff7edb",
			green: "#72f1b8", yellow: "#fede5d", red: "#fe4450", blue: "#36f9f6"
		},
		{
			id: "horizon",
			name: "Horizon",
			dark: true,
			bg: "#1c1e26", bgAlt: "#232530", border: "#2e303e",
			fg: "#d5d8da", fgDim: "#6c6f93", accent: "#e95678",
			green: "#29d398", yellow: "#fab795", red: "#e95678", blue: "#26bbd9"
		},
		{
			id: "poimandres",
			name: "Poimandres",
			dark: true,
			bg: "#1b1e28", bgAlt: "#252b37", border: "#404758",
			fg: "#e4f0fb", fgDim: "#767c9d", accent: "#5de4c7",
			green: "#5de4c7", yellow: "#fffac2", red: "#d0679d", blue: "#89ddff"
		},
		{
			id: "vesper",
			name: "Vesper",
			dark: true,
			bg: "#101010", bgAlt: "#1c1c1c", border: "#343434",
			fg: "#d0d0d0", fgDim: "#707070", accent: "#ffc799",
			green: "#99ffe4", yellow: "#ffc799", red: "#ff8080", blue: "#8eb8e5"
		},
		{
			id: "github-dimmed",
			name: "GitHub Dimmed",
			dark: true,
			bg: "#22272e", bgAlt: "#2d333b", border: "#444c56",
			fg: "#adbac7", fgDim: "#768390", accent: "#539bf5",
			green: "#57ab5a", yellow: "#c69026", red: "#e5534b", blue: "#6cb6ff"
		},
		{
			id: "github-light",
			name: "GitHub Light",
			dark: false,
			bg: "#ffffff", bgAlt: "#f6f8fa", border: "#d0d7de",
			fg: "#24292f", fgDim: "#6e7781", accent: "#0969da",
			green: "#1a7f37", yellow: "#9a6700", red: "#cf222e", blue: "#0550ae"
		},
		{
			id: "ayu-light",
			name: "Ayu Light",
			dark: false,
			bg: "#fafafa", bgAlt: "#f0f0f0", border: "#d9d8d7",
			fg: "#5c6166", fgDim: "#8a9199", accent: "#ff9940",
			green: "#86b300", yellow: "#f2ae49", red: "#f07171", blue: "#399ee6"
		},
		{
			id: "kanagawa-dragon",
			name: "Kanagawa Dragon",
			dark: true,
			bg: "#181616", bgAlt: "#282727", border: "#393836",
			fg: "#c5c9c5", fgDim: "#737c73", accent: "#8ba4b0",
			green: "#8a9a7b", yellow: "#c4b28a", red: "#c4746e", blue: "#8ba4b0"
		},
		{
			id: "kanagawa-lotus",
			name: "Kanagawa Lotus",
			dark: false,
			bg: "#f2ecbc", bgAlt: "#e7dba0", border: "#d5cea3",
			fg: "#545464", fgDim: "#8a8980", accent: "#4d699b",
			green: "#6f894e", yellow: "#77713f", red: "#c84053", blue: "#597b75"
		},
		{
			id: "dayfox",
			name: "Dayfox",
			dark: false,
			bg: "#f6f2ee", bgAlt: "#e4dcd4", border: "#cdcecf",
			fg: "#3d2b5a", fgDim: "#837a72", accent: "#287980",
			green: "#618774", yellow: "#ac5402", red: "#a5222f", blue: "#2848a9"
		},
		{
			id: "dawnfox",
			name: "Dawnfox",
			dark: false,
			bg: "#faf4ed", bgAlt: "#ebe5df", border: "#d0d8d8",
			fg: "#575279", fgDim: "#9893a5", accent: "#907aa9",
			green: "#618774", yellow: "#ea9d34", red: "#b4637a", blue: "#286983"
		},
		{
			id: "duskfox",
			name: "Duskfox",
			dark: true,
			bg: "#232136", bgAlt: "#2d2a45", border: "#433c59",
			fg: "#e0def4", fgDim: "#6e6a86", accent: "#c4a7e7",
			green: "#a3be8c", yellow: "#f6c177", red: "#eb6f92", blue: "#569fba"
		},
		{
			id: "carbonfox",
			name: "Carbonfox",
			dark: true,
			bg: "#161616", bgAlt: "#252525", border: "#3a3a3a",
			fg: "#f2f4f8", fgDim: "#7b7c7e", accent: "#78a9ff",
			green: "#25be6a", yellow: "#f1c21b", red: "#ee5396", blue: "#33b1ff"
		},
		{
			id: "terafox",
			name: "Terafox",
			dark: true,
			bg: "#152528", bgAlt: "#1d3337", border: "#2f4f54",
			fg: "#e6eaea", fgDim: "#6d7f8b", accent: "#5a93aa",
			green: "#7aa4a1", yellow: "#fda47f", red: "#e85c51", blue: "#5a93aa"
		},
		{
			id: "sonokai",
			name: "Sonokai",
			dark: true,
			bg: "#2c2e34", bgAlt: "#363944", border: "#414550",
			fg: "#e2e2e3", fgDim: "#7f8490", accent: "#76cce0",
			green: "#9ed072", yellow: "#e7c664", red: "#fc5d7c", blue: "#76cce0"
		},
		{
			id: "edge-light",
			name: "Edge Light",
			dark: false,
			bg: "#fafafa", bgAlt: "#eef1f4", border: "#dde2e7",
			fg: "#4b505b", fgDim: "#8790a0", accent: "#5079be",
			green: "#608e32", yellow: "#be7e05", red: "#d05858", blue: "#5079be"
		},
		{
			id: "iceberg",
			name: "Iceberg",
			dark: true,
			bg: "#161821", bgAlt: "#1e2132", border: "#2a3158",
			fg: "#c6c8d1", fgDim: "#6b7089", accent: "#84a0c6",
			green: "#b5bf82", yellow: "#e2a478", red: "#e27878", blue: "#84a0c6"
		},
		{
			id: "jellybeans",
			name: "Jellybeans",
			dark: true,
			bg: "#151515", bgAlt: "#1c1c1c", border: "#302028",
			fg: "#e8e8d3", fgDim: "#888888", accent: "#8fbfdc",
			green: "#99ad6a", yellow: "#fad07a", red: "#cf6a4c", blue: "#8197bf"
		},
		{
			id: "srcery",
			name: "Srcery",
			dark: true,
			bg: "#1c1b19", bgAlt: "#2d2c29", border: "#4e4e4e",
			fg: "#fce8c3", fgDim: "#918175", accent: "#fbb829",
			green: "#519f50", yellow: "#fbb829", red: "#ef2f27", blue: "#2c78bf"
		},
		{
			id: "tomorrow-night",
			name: "Tomorrow Night",
			dark: true,
			bg: "#1d1f21", bgAlt: "#282a2e", border: "#373b41",
			fg: "#c5c8c6", fgDim: "#969896", accent: "#81a2be",
			green: "#b5bd68", yellow: "#f0c674", red: "#cc6666", blue: "#8abeb7"
		},
		{
			id: "tomorrow-light",
			name: "Tomorrow Light",
			dark: false,
			bg: "#ffffff", bgAlt: "#efefef", border: "#d6d6d6",
			fg: "#4d4d4c", fgDim: "#8e908c", accent: "#4271ae",
			green: "#718c00", yellow: "#eab700", red: "#c82829", blue: "#3e999f"
		},
		{
			id: "base16-ocean",
			name: "Base16 Ocean",
			dark: true,
			bg: "#2b303b", bgAlt: "#343d46", border: "#4f5b66",
			fg: "#c0c5ce", fgDim: "#65737e", accent: "#8fa1b3",
			green: "#a3be8c", yellow: "#ebcb8b", red: "#bf616a", blue: "#96b5b4"
		},
		{
			id: "challenger-deep",
			name: "Challenger Deep",
			dark: true,
			bg: "#1e1c31", bgAlt: "#2a2740", border: "#565575",
			fg: "#cbe3e7", fgDim: "#8a889d", accent: "#91ddff",
			green: "#95ffa4", yellow: "#ffe9aa", red: "#ff8080", blue: "#65b2ff"
		},
		{
			id: "moonfly",
			name: "Moonfly",
			dark: true,
			bg: "#080808", bgAlt: "#1c1c1c", border: "#323437",
			fg: "#bdbdbd", fgDim: "#808080", accent: "#80a0ff",
			green: "#8cc85f", yellow: "#e3c78a", red: "#ff5454", blue: "#79dac8"
		},
		{
			id: "tokyo-night-moon",
			name: "Tokyo Night Moon",
			dark: true,
			bg: "#222436", bgAlt: "#2f334d", border: "#444a73",
			fg: "#c8d3f5", fgDim: "#636da6", accent: "#82aaff",
			green: "#c3e88d", yellow: "#ffc777", red: "#ff757f", blue: "#86e1fc"
		},
		{
			id: "oceanic-next",
			name: "Oceanic Next",
			dark: true,
			bg: "#1b2b34", bgAlt: "#343d46", border: "#4f5b66",
			fg: "#cdd3de", fgDim: "#65737e", accent: "#6699cc",
			green: "#99c794", yellow: "#fac863", red: "#ec5f67", blue: "#5fb3b3"
		},
		{
			id: "papercolor-dark",
			name: "PaperColor Dark",
			dark: true,
			bg: "#1c1c1c", bgAlt: "#303030", border: "#444444",
			fg: "#d0d0d0", fgDim: "#808080", accent: "#5fafd7",
			green: "#5faf5f", yellow: "#d7af5f", red: "#af005f", blue: "#5fafd7"
		},
		{
			id: "papercolor-light",
			name: "PaperColor Light",
			dark: false,
			bg: "#eeeeee", bgAlt: "#e4e4e4", border: "#d0d0d0",
			fg: "#444444", fgDim: "#878787", accent: "#005f87",
			green: "#008700", yellow: "#d75f00", red: "#af0000", blue: "#0087af"
		},
		{
			id: "modus-vivendi",
			name: "Modus Vivendi",
			dark: true,
			bg: "#000000", bgAlt: "#1e1e1e", border: "#535353",
			fg: "#ffffff", fgDim: "#989898", accent: "#2fafff",
			green: "#44bc44", yellow: "#d0bc00", red: "#ff5f59", blue: "#00d3d0"
		},
		{
			id: "modus-operandi",
			name: "Modus Operandi",
			dark: false,
			bg: "#ffffff", bgAlt: "#f2f2f2", border: "#c4c4c4",
			fg: "#000000", fgDim: "#595959", accent: "#0031a9",
			green: "#006800", yellow: "#6f5500", red: "#a60000", blue: "#005e8b"
		},
		{
			id: "zenbones-dark",
			name: "Zenbones Dark",
			dark: true,
			bg: "#1c1917", bgAlt: "#292524", border: "#3b3835",
			fg: "#b4bdc3", fgDim: "#77706a", accent: "#6099c0",
			green: "#819b69", yellow: "#b77e64", red: "#de6e7c", blue: "#6099c0"
		},
		{
			id: "zenbones-light",
			name: "Zenbones Light",
			dark: false,
			bg: "#f0edec", bgAlt: "#e2dedb", border: "#cbc6c1",
			fg: "#2c363c", fgDim: "#7a7673", accent: "#286486",
			green: "#4f6c31", yellow: "#944927", red: "#a8334c", blue: "#286486"
		},
		{
			id: "tender",
			name: "Tender",
			dark: true,
			bg: "#282828", bgAlt: "#323232", border: "#4c4c4c",
			fg: "#eeeeee", fgDim: "#6a6a6a", accent: "#b3deef",
			green: "#c9d05c", yellow: "#ffc24b", red: "#f43753", blue: "#73cef4"
		},
		{
			id: "darcula",
			name: "Darcula",
			dark: true,
			bg: "#2b2b2b", bgAlt: "#3c3f41", border: "#4e5254",
			fg: "#a9b7c6", fgDim: "#808080", accent: "#6897bb",
			green: "#6a8759", yellow: "#ffc66d", red: "#cc7832", blue: "#6897bb"
		},
		{
			id: "vscode-dark",
			name: "VS Code Dark+",
			dark: true,
			bg: "#1e1e1e", bgAlt: "#252526", border: "#3c3c3c",
			fg: "#d4d4d4", fgDim: "#808080", accent: "#569cd6",
			green: "#b5cea8", yellow: "#dcdcaa", red: "#f44747", blue: "#4fc1ff"
		},
		{
			id: "vscode-light",
			name: "VS Code Light",
			dark: false,
			bg: "#ffffff", bgAlt: "#f3f3f3", border: "#d4d4d4",
			fg: "#333333", fgDim: "#6a737d", accent: "#0066b8",
			green: "#008000", yellow: "#795e26", red: "#cd3131", blue: "#0451a5"
		},
		{
			id: "apprentice",
			name: "Apprentice",
			dark: true,
			bg: "#262626", bgAlt: "#303030", border: "#444444",
			fg: "#bcbcbc", fgDim: "#6c6c6c", accent: "#5f87af",
			green: "#87af87", yellow: "#ffffaf", red: "#af5f5f", blue: "#5f87af"
		},
		{
			id: "lackluster",
			name: "Lackluster",
			dark: true,
			bg: "#080808", bgAlt: "#101010", border: "#2a2a2a",
			fg: "#deeeed", fgDim: "#7a7a7a", accent: "#7788aa",
			green: "#789978", yellow: "#cfb572", red: "#d70000", blue: "#7788aa"
		},
		{
			id: "city-lights",
			name: "City Lights",
			dark: true,
			bg: "#1d252c", bgAlt: "#28323a", border: "#41505e",
			fg: "#b7c5d3", fgDim: "#4d5660", accent: "#539afc",
			green: "#8bd49c", yellow: "#ebbf83", red: "#d95468", blue: "#70e1e8"
		},
		{
			id: "andromeda",
			name: "Andromeda",
			dark: true,
			bg: "#23262e", bgAlt: "#2d313b", border: "#3d4350",
			fg: "#d5ced9", fgDim: "#5c6370", accent: "#00e8c6",
			green: "#96e072", yellow: "#ffe66d", red: "#ee5d43", blue: "#7cb7ff"
		},
		{
			id: "shades-of-purple",
			name: "Shades of Purple",
			dark: true,
			bg: "#2d2b55", bgAlt: "#1e1e3f", border: "#5d57a8",
			fg: "#ffffff", fgDim: "#a599e9", accent: "#fad000",
			green: "#3ad900", yellow: "#fad000", red: "#ff628c", blue: "#9effff"
		},
		{
			id: "flexoki-dark",
			name: "Flexoki Dark",
			dark: true,
			bg: "#100f0f", bgAlt: "#1c1b1a", border: "#343331",
			fg: "#cecdc3", fgDim: "#878580", accent: "#da702c",
			green: "#879a39", yellow: "#d0a215", red: "#d14d41", blue: "#4385be"
		},
		{
			id: "flexoki-light",
			name: "Flexoki Light",
			dark: false,
			bg: "#fffcf0", bgAlt: "#f2f0e5", border: "#dad8ce",
			fg: "#100f0f", fgDim: "#6f6e69", accent: "#bc5215",
			green: "#66800b", yellow: "#ad8301", red: "#af3029", blue: "#205ea6"
		}
	]

	readonly property string fallbackId: "gruvbox"

	// Unknown ids (a hand-edited state file, a theme that was removed) fall
	// back rather than leaving the bar with no palette at all.
	function get(id: string): var {
		return list.find(t => t.id === id) ?? list.find(t => t.id === fallbackId);
	}
}
