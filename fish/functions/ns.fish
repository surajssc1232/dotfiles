function ns --wraps="nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history" --description "alias ns nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history"
    nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history $argv
end
