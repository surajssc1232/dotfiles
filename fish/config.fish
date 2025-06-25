if status is-interactive
    # Commands to run in interactive sessions can go here

    starship init fish | source
end

if type -q bass
    bass source ~/.env
end

function man
    command man $argv | col -bx | bat -l man -p
end

# Created by `pipx` on 2023-10-13 17:54:22
set PATH $PATH /home/can/.local/bin
set PATH $PATH /home/can/.cargo/bin

# Fish configuration file - place in ~/.config/fish/config.fish

# Initialize Starship prompt
starship init fish | source

# Aliases
alias c='clear'
alias q='exit'
alias tt='tweet'
alias nvimc='nvim ~/.config/nvim/init.lua'
alias gc='nvim ~/.config/ghostty/config'
alias fc-list='fc-list --format="%{family}\n" | sort'
alias cursor_reset='curl -sL dub.sh/cursorreset | python3'
alias gemcli='gemini -m "gemini-2.5-flash-preview-05-20"'
alias hx='helix'
alias py='python'

# Function to list commands with descriptions
function list_commands_with_desc
    echo $PATH | tr ':' '\n' | while read -l dir
        if test -d "$dir"
            find "$dir" -maxdepth 1 -type f -executable 2>/dev/null
        end
    end | awk '!seen[$0]++' | while read -l cmd
        set name (basename "$cmd")
        set description (whatis "$name" 2>/dev/null | head -n 1)
        if test -z "$description"
            set description "No description"
        end
        echo -e "$name\t$description"
    end | sort -u | fzf --delimiter='\t' --with-nth=1 --preview='man {1} || echo "No manual entry for {1}"' --preview-window=up:3
end

# Vim with fzf
function vimfzf
    set file (find ~ -type f | fzf --preview 'bat --color=always {}')
    if test -n "$file"
        nvim "$file"
    end
end

# Enhanced 'l' function
function l
    if test "$argv[1]" = -t
        exa -T $argv[2..]
    else
        exa --icons $argv
    end
end

# Open notes function
function open_notes
    ~/.local/bin/note.sh
end

# Enhanced man function
function man
    command man $argv | col -bx | bat -l man -p
end

# Environment Variables
set -x JAVA_HOME /usr/lib/jvm/java-24-openjdk/lib/javac
set -x INSTA_RAPIDAPI_KEY 779c19efccmsh6d0190d61a9be00p1c2bc3jsn7fcbde842cc3
set -x BUN_INSTALL "$HOME/.bun"
set -x LUA_PATH "$HOME/.luarocks/share/lua/5.4/?.lua;$HOME/.luarocks/share/lua/5.4/?/init.lua;;"
set -x LUA_CPATH "$HOME/.luarocks/lib/lua/5.4/?.so;;"
set -x SYSTEMD_EDITOR /usr/bin/nvim
set -x EDITOR nvim
set -x NNN_OPENER nvim
set -x PAGER less
set -x MANPAGER less
set -x GEMINI_API_KEY AIzaSyAa2EP_AqNp0Lr8dEAfQMdGzq2HOPRHBYU
set -x NIXPKGS_ALLOW_UNFREE 1

# PATH modifications
fish_add_path $JAVA_HOME/bin
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin
fish_add_path $HOME/go/bin
fish_add_path $BUN_INSTALL/bin
fish_add_path $HOME/.nix-profile/bin

# Key bindings
bind \cn vimfzf
bind \cu list_commands_with_desc
# Note: Fish uses different key binding syntax, Alt+D would be \ed
bind \ed open_notes

# Source additional files if they exist
if test -f ~/tweet_api.fish
    source ~/tweet_api.fish
end

if test -f ~/gemini-cli.fish
    source ~/gemini-cli.fish
end

# Load Nix profile
if test -e /home/suraj/.nix-profile/etc/profile.d/nix.sh
    bass source /home/suraj/.nix-profile/etc/profile.d/nix.sh
end

# Auto-start tmux (place at end of config)
if status is-interactive; and not set -q TMUX; and command -q tmux
    exec tmux
end

# Run fastfetch on startup
if status is-interactive
    fastfetch --config examples/8.jsonc
end

fzf_key_bindings
