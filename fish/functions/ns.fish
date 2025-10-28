function ns -d "Search and install Nix packages"
    set -l selected (nix-search-tv print | grep -v "options" | fzf --preview 'nix-search-tv preview {}' --scheme=history)
    
    if test -n "$selected"
        # Extract just the package name
        set -l pkg_name (echo $selected | awk -F"/" '{print $NF}' | string trim)
        
        echo ""
        echo "Selected: $pkg_name"
        read -P "Install this package? [Y/n] " -n 1 confirm
        
        if test "$confirm" = "y" -o "$confirm" = "Y" -o -z "$confirm"
            nix-install-pkg $pkg_name
        else
            echo "Cancelled"
        end
    end
    
    commandline -f repaint
end
