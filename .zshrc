# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
# End of lines configured by zsh-newuser-install

# The following lines were added by compinstall
autoload -Uz add-zle-hook-widget
autoload -Uz compinit
compinit
# End of lines added by compinstall

export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#b7bdf8,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796 \
--color=selected-bg:#494d64 \
--color=border:#363a4f,label:#cad3f5"

eval "$(starship init zsh)"

# Source plugins
ZSH_AUTOSUGGEST_STRATEGY=(completion history)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8,bold"

# Aliases
alias c='clear'
alias q='exit'
alias l='exa -l'
alias ls='exa --icons --group-directories-first'

# Custom function for opening files with nvim via fzf
function nvfzf() {
 local selected_file=$(find / -type f 2>/dev/null | fzf --preview 'bat --color=always {}' --preview-window=up:3)
 if [[ -n "$selected_file" ]]; then
 nvim "$selected_file"
 fi
}

# Custom function for commands with descriptions
function list_commands_with_desc() {
 echo "$PATH" | tr ':' '\n' | while read -r dir; do
 if [[ -d "$dir" ]]; then
  find "$dir" -type f -executable 2>/dev/null | while read -r cmd; do
  description=$(whatis "$(basename "$cmd")" 2>/dev/null | head -n 1) || description="No description"
  echo "$(basename "$cmd")\t$description"
  done
 fi
 done | fzf --delimiter='\t' --with-nth=1 --preview='man {} || echo "No manual entry"' --preview-window=up:3
}

# Vim with fzf
function vimfzf() {
 local file=$(find ~ -type f | fzf --preview 'bat --color=always {}')
 [ -n "$file" ] && nvim "$file"
}

# Bind Ctrl+N to vimfzf
bindkey -s '^N' 'vimfzf\n'

# Environment variables
export PATH=$PATH:/home/suraj/.spicetify:/home/suraj/.local/bin
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

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

fastfetch --config examples/14.jsonc
source ~/tweet_api.zsh
