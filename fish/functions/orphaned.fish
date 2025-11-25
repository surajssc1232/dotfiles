function orphaned
     sudo pacman -Rns $(pacman -Qdtq)
end
