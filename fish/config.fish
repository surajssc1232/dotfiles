if status is-interactive
    # Commands to run in interactive sessions can go here
    alias ns="nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history"
    abbr -a --position anywhere -- --help '--help | bat -plhelp'
    abbr -a --position anywhere -- -h '-h | bat -plhelp'

    alias fp='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}"'
    export MANPAGER="bat -plman"
end
