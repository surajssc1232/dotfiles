-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.
config.enable_tab_bar = false
config.use_fancy_tab_bar=false
config.tab_bar_at_bottom=false

config.window_decorations = 'NONE'
config.hide_tab_bar_if_only_one_tab=true

-- padding
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.adjust_window_size_when_changing_font_size = false

config.window_close_confirmation = 'NeverPrompt'

-- or, changing the font size and color scheme.
config.font_size = 12

config.color_scheme = 'Gruvbox Dark (Gogh)'

config.keys = {
  { key = '0',  mods = 'CTRL', action = wezterm.action.ResetFontSize, },
  { key = '-',  mods = 'ALT',  action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' }, },
  { key = '\\', mods = 'ALT',  action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'h',  mods = 'ALT',  action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'j',  mods = 'ALT',  action = wezterm.action.ActivatePaneDirection 'Down' },
  { key = 'k',  mods = 'ALT',  action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'l',  mods = 'ALT',  action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'x',  mods = 'ALT',  action = wezterm.action.CloseCurrentPane { confirm = false } },
  { key = 'n',  mods = 'ALT',  action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  { key = '1',  mods = 'ALT',  action = wezterm.action.ActivateTab(0) },
  { key = '2',  mods = 'ALT',  action = wezterm.action.ActivateTab(1) },
  { key = '3',  mods = 'ALT',  action = wezterm.action.ActivateTab(2) },
}

-- Finally, return the configuration to wezterm:
return config
