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

# Create a custom widget/function
# Start tmux automatically
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

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
    tree "$@"  # Run tree with arguments when -t is passed
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

export PATH=$PATH:~/.cargo/bin/

alias fc-list="fc-list --format='%{family}\n' | sort"
alias cursor_reset="curl -sL dub.sh/cursorreset | python3"


source ~/gemini-cli.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
source /usr/share/zsh/plugins/zsh-auto-venv/auto-venv.zsh
export PATH="$HOME/go/bin/:$PATH"
alias gemcli="gemini -m "gemini-2.5-flash-preview-04-17""

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


if [ -z "$TMUX" ] && ! pgrep -x "tmux" > /dev/null; then
  exec tmux
fi


# Created by `pipx` on 2025-06-05 15:25:51
export PATH="$PATH:/home/suraj/.local/bin/"

