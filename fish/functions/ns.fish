function ns --wraps="nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history"
    nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history
end
