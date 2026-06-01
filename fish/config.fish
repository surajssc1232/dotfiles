if status is-interactive
    # Commands to run in interactive sessions can go here
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    fastfetch --config examples/14.jsonc
    set -U fish_greeting ""
end


