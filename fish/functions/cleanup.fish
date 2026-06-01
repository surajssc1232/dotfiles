function cleanup --description "Remove package cache and unused orphans"
    echo "--- Cleaning package cache (keeping last 3) ---"
    sudo paccache -r

    echo "--- Checking for orphaned packages ---"
    set orphans (pacman -Qtdq)
    if test -n "$orphans"
        sudo pacman -Rns $orphans
    else
        echo "No orphaned packages to remove."
    end
end
