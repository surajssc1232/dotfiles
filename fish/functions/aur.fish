function aur --description "Search AUR packages"
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
end
