function nru --wraps='sudo nixos-rebuild switch --upgrade' --description 'alias nru=sudo nixos-rebuild switch --upgrade'
    sudo nixos-rebuild switch --upgrade $argv
end
