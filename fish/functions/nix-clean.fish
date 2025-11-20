function nix-clean --wraps='nix-collect-garbage --delete-old; nix-store --gc; nix-collect-garbage --delete-older-than 2d' --wraps='sudo nix-collect-garbage --delete-old; sudo nix-store --gc;sudo nix-collect-garbage --delete-older-than 2d' --description 'alias nix-clean=nix-collect-garbage --delete-old; nix-store --gc; nix-collect-garbage --delete-older-than 2d'
    sudo nix-collect-garbage --delete-old
    sudo nix-store --gc
    sudo nix-collect-garbage --delete-older-than 2d $argv
end
