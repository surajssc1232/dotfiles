function nixc --wraps='hx /etc/nixos/configuration.nix' --description 'alias nixc=hx /etc/nixos/configuration.nix'
    sudo nvim /etc/nixos/configuration.nix $argv
end
