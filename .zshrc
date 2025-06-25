# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
# End of lines configured by zsh-newuser-install

# The following lines were added by compinstall
autoload -Uz add-zle-hook-widget
autoload -Uz compinit
compinit

eval "$(starship init zsh)"
# Source plugins
ZSH_AUTOSUGGEST_STRATEGY=(completion history)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8,bold"

# Aliases
alias c='clear'
alias q='exit'
alias l='exa --icons'

list_commands_with_desc() {
  echo "$PATH" | tr ':' '\n' | while read -r dir; do
    if [[ -d "$dir" ]]; then
      find "$dir" -maxdepth 1 -type f -executable 2>/dev/null
    fi
  done | awk '!seen[$0]++' | while read -r cmd; do
    name=$(basename "$cmd")
    description=$(whatis "$name" 2>/dev/null | head -n 1)
    if [[ -z "$description" ]]; then
      description="No description"
    fi
    echo -e "${name}\t${description}"
  done | sort -u | \
  fzf --delimiter='\t' --with-nth=1 --preview='man {1} || echo "No manual entry for {1}"' --preview-window=up:3
}

# Vim with fzf
function vimfzf() {
 local file=$(find ~ -type f | fzf --preview 'bat --color=always {}')
 [ -n "$file" ] && nvim "$file"
}

# Bind Ctrl+N to vimfzf
bindkey -s '^N' 'vimfzf\n'
bindkey -s '^U' 'list_commands_with_desc\n'



# Prompt customization
PROMPT_COMMAND='echo "----------------------------------------"'
PS1='$(starship prompt)'

# Keybindings
bindkey '^[[1;5C' forward-word # Ctrl + Right Arrow
bindkey '^[[1;5D' backward-word # Ctrl + Left Arrow
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh

# Start tmux automatically
# if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
#   exec tmux
# fi

fastfetch --config examples/8.jsonc
alias tt="tweet"

# export JAVA_HOME=/usr/lib/jvm/java-21-openjdk/bin/java
export JAVA_HOME=/usr/lib/jvm/java-24-openjdk/lib/javac
export PATH=$JAVA_HOME/bin:$PATH

alias nvimc="nvim ~/.config/nvim/init.lua"

# Remove any existing alias for 'l'
unalias l 2>/dev/null

# Define 'l' as a function
l() {
  if [[ "$1" == "-t" ]]; then
	exa -T # Run tree with arguments when -t is passed
  else
    exa --icons "$@"  # Run exa with icons for other arguments
  fi
}

source ~/tweet_api.zsh

alias gc="nvim ~/.config/ghostty/config"


export INSTA_RAPIDAPI_KEY="779c19efccmsh6d0190d61a9be00p1c2bc3jsn7fcbde842cc3"

# bun completions
[ -s "/home/suraj/.bun/_bun" ] && source "/home/suraj/.bun/_bun"
# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export LUA_PATH="$HOME/.luarocks/share/lua/5.4/?.lua;$HOME/.luarocks/share/lua/5.4/?/init.lua;;"
export LUA_CPATH="$HOME/.luarocks/lib/lua/5.4/?.so;;"

export SYSTEMD_EDITOR=/usr/bin/nvim
export EDITOR=nvim
export NNN_OPENER=nvim

export PATH=$PATH:~/.cargo/bin/

alias fc-list="fc-list --format='%{family}\n' | sort"
alias cursor_reset="curl -sL dub.sh/cursorreset | python3"


source ~/gemini-cli.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
source /usr/share/zsh/plugins/zsh-auto-venv/auto-venv.zsh
export PATH="$HOME/go/bin/:$PATH"
alias gemcli="gemini -m "gemini-2.5-flash-preview-05-20""

alias hx=helix
alias py=python


open_notes() {
    ~/.local/bin/note.sh
}
zle -N open_notes

bindkey '^[D' open_notes


export PAGER="less"
export MANPAGER="less"

man() {
    command man "$@" | col -bx | bat -l man -p
}




# Created by `pipx` on 2025-06-05 15:25:51
export PATH="$PATH:/home/suraj/.local/bin/"


if [ -e /home/suraj/.nix-profile/etc/profile.d/nix.sh ]; then . /home/suraj/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

# Auto-start fresh tmux session in interactive shell
# Auto-start fresh tmux session in interactive shell
if [[ -n "$PS1" ]] && [[ -z "$TMUX" ]] && command -v tmux &>/dev/null; then
  exec tmux
fi

export PATH="$HOME/.nix-profile/bin:$PATH"
export PATH="$HOME/.nix-profile/bin:$PATH"

export GEMINI_API_KEY='AIzaSyAa2EP_AqNp0Lr8dEAfQMdGzq2HOPRHBYU'
export NIXPKGS_ALLOW_UNFREE=1


# Function to capture the last command's output
capture_last_output() {
    # Redirect output to a file
    fc -s -1 > ~/.prev_cmd_output.txt 2>&1
}
# Run after every command
PROMPT_COMMAND="capture_last_output; $PROMPT_COMMAND"


aur() {
    echo "" | fzf \
        --disabled \
        --bind 'start:reload(paru -Sl aur | awk "{print \$2}")' \
        --bind 'change:reload(if [ -n "{q}" ]; then paru -Ss {q} | grep "^aur/" | cut -d"/" -f2 | cut -d" " -f1; else paru -Sl aur | awk "{print \$2}"; fi)' \
        --preview 'paru -Si {} 2>/dev/null | bat --color=always --plain' \
        --layout=reverse \
        --height=90% \
        --border \
        --prompt='🔍 AUR › ' \
        --header='All AUR packages | Type to search | Enter: Info | Ctrl+I: Install' \
        --bind 'enter:execute(paru -Si {} | less)' \
        --bind 'ctrl-i:execute(paru -S {} < /dev/tty > /dev/tty 2>&1)'
}

nix-search() {
    # Search and pipe to fzf with bat preview
    nix search nixpkgs "" --json 2>/dev/null | \
    jq -r 'to_entries[] | "\(.value.pname // (.key | split(".") | last))\t\(.value.description // "No description")\t\(.key)"' | \
    fzf --delimiter='\t' \
        --with-nth=1 \
        --header-lines=0 \
        --layout=reverse \
        --preview='echo "Package: {1}" | bat --style=header --color=always -l yaml; echo; echo "Description:" | bat --style=header --color=always -l yaml; echo "{2}" | bat --color=always -l markdown; echo; echo "Full Path: {3}" | bat --style=header --color=always -l yaml; echo; echo "Details:" | bat --style=header --color=always -l yaml; nix show-derivation {3} 2>/dev/null | head -20 | bat --color=always -l json || echo "No additional details available"' \
        --preview-window=right:60%:wrap \
        --header='Tab: toggle preview | Enter: copy full package name to clipboard | Ctrl+I: install package' \
        --bind='enter:execute(echo {3} | wl-copy)+abort' \
        --bind='ctrl-i:execute(nix profile install nixpkgs#{3})+abort'
}


# Ensure Emacs keymap is used (default for interactive shell)
bindkey -e

# Bind Ctrl+R to reverse-incremental history search
bindkey '^R' history-incremental-search-backward

source ~/tweet_api.zsh
