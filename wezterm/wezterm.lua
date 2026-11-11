local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Palette written by quickshell's apply-theme.sh; wezterm reloads when it changes.
local palette_path = wezterm.home_dir .. '/.local/state/quickshell/palette.json'
wezterm.add_to_config_reload_watch_list(palette_path)
local p = {
  bg = '#282828', bgAlt = '#3c3836', border = '#504945', fg = '#ebdbb2', dim = '#928374',
  accent = '#fe8019', green = '#b8bb26', yellow = '#fabd2f', red = '#fb4934', blue = '#83a598',
}
do
  local f = io.open(palette_path, 'r')
  if f then
    local ok, data = pcall(wezterm.json_parse, f:read('*a'))
    f:close()
    if ok and data then for k, v in pairs(data) do p[k] = v end end
  end
end

-- Appearance (font matches foot)
config.font = wezterm.font_with_fallback { 'JetBrainsMono Nerd Font' }
config.font_size = 12
config.line_height = 1.1

config.window_background_opacity = 0.85
config.window_decorations = 'RESIZE'
config.window_padding = { left = 16, right = 16, top = 12, bottom = 8 }
config.initial_cols = 120
config.initial_rows = 34
-- Keep the window size fixed when zooming the font (Ctrl +/-); resize the grid instead.
config.adjust_window_size_when_changing_font_size = false
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 600
config.inactive_pane_hsb = { saturation = 0.8, brightness = 0.6 }

-- Tab bar
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.show_new_tab_button_in_tab_bar = false

-- Same ANSI mapping as foot's theme.ini
config.colors = {
  foreground = p.fg,
  background = p.bg,
  cursor_bg = p.accent,
  cursor_border = p.accent,
  cursor_fg = p.bg,
  selection_bg = p.fg,
  selection_fg = p.bg,
  split = p.border,
  ansi = { p.border, p.red, p.green, p.yellow, p.blue, p.accent, p.blue, p.fg },
  brights = { p.dim, p.red, p.green, p.yellow, p.blue, p.accent, p.blue, p.fg },
  tab_bar = {
    background = p.bg,
    active_tab = { bg_color = p.accent, fg_color = p.bg, intensity = 'Bold' },
    inactive_tab = { bg_color = p.bgAlt, fg_color = p.dim },
    inactive_tab_hover = { bg_color = p.border, fg_color = p.fg },
  },
}

wezterm.on('format-tab-title', function(tab)
  local title = tab.tab_title ~= '' and tab.tab_title or tab.active_pane.title
  local idx = tab.tab_index + 1
  return ' ' .. idx .. ': ' .. title .. ' '
end)

wezterm.on('update-right-status', function(window, pane)
  local cwd = pane:get_current_working_dir()
  local dir = cwd and (cwd.file_path or tostring(cwd)):gsub(os.getenv('HOME') or '', '~') or ''
  window:set_right_status(wezterm.format {
    { Foreground = { Color = p.blue } }, { Text = '  ' .. dir .. '  ' },
    { Foreground = { Color = p.yellow } }, { Text = ' ' .. wezterm.strftime '%H:%M' .. '  ' },
  })
end)

-- Keys (leader = Ctrl+a)
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.keys = {
  { key = '|', mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = false } },
  { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },
  { key = ',', mods = 'LEADER', action = act.PromptInputLine {
    description = 'Rename tab',
    action = wezterm.action_callback(function(win, _, line) if line then win:active_tab():set_title(line) end end),
  } },
  { key = 'a', mods = 'LEADER|CTRL', action = act.SendKey { key = 'a', mods = 'CTRL' } },
}
for i = 1, 9 do
  table.insert(config.keys, { key = tostring(i), mods = 'LEADER', action = act.ActivateTab(i - 1) })
end

config.scrollback_lines = 10000
config.audible_bell = 'Disabled'
config.window_close_confirmation = 'NeverPrompt'

return config
