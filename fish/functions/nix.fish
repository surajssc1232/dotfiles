function nix-search
    # Search and pipe to fzf with bat preview
    nix search nixpkgs "" --json 2>/dev/null | jq -r 'to_entries[] | "\(.value.pname // (.key | split(".") | last))\t\(.value.description // "No description")\t\(.key)"' | fzf --delimiter='\t' \
        --with-nth=1 \
        --header-lines=0 \
        --layout=reverse \
        --preview='echo "Package: {1}" | bat --style=header --color=always -l yaml; echo; echo "Description:" | bat --style=header --color=always -l yaml; echo "{2}" | bat --color=always -l markdown; echo; echo "Full Path: {3}" | bat --style=header --color=always -l yaml; echo; echo "Details:" | bat --style=header --color=always -l yaml; nix show-derivation {3} 2>/dev/null | head -20 | bat --color=always -l json || echo "No additional details available"' \
        --preview-window=right:60%:wrap \
        --header='Tab: toggle preview | Enter: copy full package name to clipboard | Ctrl+I: install package' \
        --bind='enter:execute(echo {3} | wl-copy)+abort' \
        --bind='ctrl-i:execute(nix profile install nixpkgs#{3})+abort'
end
