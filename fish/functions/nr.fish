function nr --wraps='sudo nixos-rebuild switch' --description 'alias nr=sudo nixos-rebuild switch'
    sudo nixos-rebuild switch $argv
end
