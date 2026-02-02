if status is-interactive
    bind \em toggle-touchpad
    starship init fish | source
    zoxide init fish | source
    set -U fish_greeting
    fastfetch -s OS:HOST:Kernel:Uptime:Shell:WM:Terminal:CPU:GPU:Disk:Memory

end

set -gx NIXPKGS_ALLOW_UNFREE 1
