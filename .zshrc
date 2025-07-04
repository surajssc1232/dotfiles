# History settings
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# Completion settings
autoload -Uz compinit
compinit

# cd settings
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Globbing settings
setopt EXTENDED_GLOB
setopt NO_CASE_GLOB
setopt NULL_GLOB

# Other options
setopt NO_HUP
setopt NO_CHECK_JOBS

# Key bindings
bindkey -v
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias gs='git status'
alias ga='git add .'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate'
alias ta='tmux attach'
alias tad='tmux attach -d'
alias ts='tmux new-session'
alias tl='tmux list-sessions'
alias tksv='tmux kill-server'
alias tkss='tmux kill-session'
alias h='history'
alias j='jobs -l'
alias which='type -a'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias l=exa --icons
alias fclist='fc-list : family'
alias saplogon='xfreerdp3 /v:115.245.150.98:9001 /u:USER517 /p:Welcome@2025 /f'


# Environment variables
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'
export LESS='-R'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# PATH settings
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"



# Starship prompt
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
else
    echo "Starship not found. Install it with:"
    echo "curl -sS https://starship.rs/install.sh | sh"
fi

# FZF-Tab completion
if [[ -f ~/.zsh/fzf-tab/fzf-tab.plugin.zsh ]]; then
    source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
else
    echo "Warning: fzf-tab plugin not found at ~/.zsh/fzf-tab/fzf-tab.plugin.zsh"
fi

# Zsh autosuggestions
if [[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
else
    echo "Warning: zsh-autosuggestions plugin not found at ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# API Keys (consider moving to a separate private file)


if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

source ~/.zsh/fzf-history-search/zsh-fzf-history-search.zsh

# fastfetch --config examples/13.jsonc


source ~/GEMINI_API_KEY.zsh