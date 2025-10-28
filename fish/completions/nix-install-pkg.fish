# ~/.config/fish/completions/nix-install-pkg.fish
complete -c nix-install-pkg -f -a '(
    nix-search-tv print | grep -v "options" | awk -F"/" \'{print $NF}\' | string trim
)'
