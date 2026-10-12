#!/usr/bin/env bash
# Pushes one palette out to foot, ghostty, helium and neovim, then reloads the ones
# that are running. Called by Config.setTheme with the palette as arguments.
#   apply-theme.sh bg bgAlt border fg fgDim accent green yellow red blue glass(0|1)
set -u
bg=${1#\#} bgAlt=${2#\#} border=${3#\#} fg=${4#\#} dim=${5#\#}
accent=${6#\#} green=${7#\#} yellow=${8#\#} red=${9#\#} blue=${10#\#}
glass=${11:-0}
# Light themes have dark text, which needs more of the pale background
# behind it to stay readable over a wallpaper.
lum=$(( (2126 * 0x${bg:0:2} + 7152 * 0x${bg:2:2} + 722 * 0x${bg:4:2}) / 10000 ))
if [ "$lum" -gt 127 ]; then opacity=0.85; else opacity=0.65; fi

# ---- foot: both sections identical so the USR1 switch always lands on it ----
foot_colors() {
	[ "$glass" = 1 ] && echo "alpha=$opacity"
	cat <<EOT
background=$bg
foreground=$fg
regular0=$border
regular1=$red
regular2=$green
regular3=$yellow
regular4=$blue
regular5=$accent
regular6=$blue
regular7=$fg
bright0=$dim
bright1=$red
bright2=$green
bright3=$yellow
bright4=$blue
bright5=$accent
bright6=$blue
bright7=$fg
selection-foreground=$fg
selection-background=$border
EOT
}
{ echo "[colors-dark]"; foot_colors; echo; echo "[colors-light]"; foot_colors; } > ~/.config/foot/theme.ini
# foot never reloads its config, so recolor open windows by writing OSC
# sequences to each one's pty (foot's children hold the slave end on stdin).
printf -v osc '\033]10;#%s\033\\\033]11;#%s\033\\\033]12;#%s\033\\' "$fg" "$bg" "$accent"
i=0
for c in $border $red $green $yellow $blue $accent $blue $fg $dim $red $green $yellow $blue $accent $blue $fg; do
	printf -v seq '\033]4;%d;#%s\033\\' "$i" "$c"; osc+=$seq; i=$((i + 1))
done
for fpid in $(pgrep -x foot); do
	for child in $(pgrep -P "$fpid"); do
		tty=$(readlink "/proc/$child/fd/0")
		case $tty in /dev/pts/*) printf '%s' "$osc" > "$tty" 2>/dev/null ;; esac
	done
done

# ---- ghostty ----
{
	echo "background = #$bg"
	echo "foreground = #$fg"
	echo "cursor-color = #$accent"
	echo "selection-background = #$border"
	echo "selection-foreground = #$fg"
	if [ "$glass" = 1 ]; then
		echo "background-opacity = $opacity"
		echo "background-blur = true"
	else
		echo "background-opacity = 1"
	fi
	i=0
	for c in $border $red $green $yellow $blue $accent $blue $fg $dim $red $green $yellow $blue $accent $blue $fg; do
		echo "palette = $i=#$c"; i=$((i + 1))
	done
} > ~/.config/ghostty/themes/quickshell
pkill -USR2 -x '\.?ghostty.*' 2>/dev/null

# ---- helium (Chromium): theme extension rewritten on every change. Load
# ~/.local/share/helium-theme once via chrome://extensions -> Load unpacked,
# then hit its reload button (or restart) to pick up a new palette. ----
rgb() { printf '[%d,%d,%d]' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
hdir=~/.local/share/helium-theme
mkdir -p "$hdir"
cat > "$hdir/manifest.json" <<EOT
{
  "manifest_version": 3,
  "name": "Quickshell Theme",
  "version": "1.$(date +%s)",
  "theme": {
    "colors": {
      "frame": $(rgb "$bg"),
      "frame_inactive": $(rgb "$bg"),
      "frame_incognito": $(rgb "$bgAlt"),
      "frame_incognito_inactive": $(rgb "$bgAlt"),
      "toolbar": $(rgb "$bgAlt"),
      "toolbar_text": $(rgb "$fg"),
      "tab_text": $(rgb "$fg"),
      "tab_background_text": $(rgb "$dim"),
      "bookmark_text": $(rgb "$fg"),
      "button_background": $(rgb "$bgAlt"),
      "omnibox_background": $(rgb "$bg"),
      "omnibox_text": $(rgb "$fg"),
      "ntp_background": $(rgb "$bg"),
      "ntp_text": $(rgb "$fg"),
      "ntp_link": $(rgb "$accent"),
      "ntp_header": $(rgb "$bgAlt"),
      "background_tab": $(rgb "$bg"),
      "control_background": $(rgb "$bgAlt"),
      "toolbar_button_icon": $(rgb "$fg")
    },
    "properties": { "ntp_background_alignment": "center" }
  }
}
EOT

# ---- niri: window border and focus ring, in a file config.kdl includes.
# niri watches its config, includes too, so this applies straight away. ----
cat > ~/.config/niri/quickshell-colors.kdl <<EOT
// Written by quickshell's apply-theme.sh on every theme change.
layout {
    focus-ring {
        active-color "#$accent"
        inactive-color "#$border"
    }
    border {
        active-color "#$accent"
        inactive-color "#$border"
        urgent-color "#$red"
    }
}
EOT

# ---- neovim: palette for colors/quickshell.lua, then reload live instances ----
mkdir -p ~/.local/state/quickshell
cat > ~/.local/state/quickshell/palette.json <<EOT
{"bg":"#$bg","bgAlt":"#$bgAlt","border":"#$border","fg":"#$fg","dim":"#$dim","accent":"#$accent","green":"#$green","yellow":"#$yellow","red":"#$red","blue":"#$blue","glass":$([ "$glass" = 1 ] && echo true || echo false)}
EOT
for sock in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/nvim.*.0; do
	[ -S "$sock" ] && nvim --server "$sock" --remote-send '<Cmd>colorscheme quickshell<CR>' >/dev/null 2>&1
done
exit 0
