# Defined in ~/.config/fish/functions/fish_prompt.fish
# Based on fish's default prompt, with a venv-aware colour scheme.
function fish_prompt --description 'Write out the prompt'
    set -l last_pipestatus $pipestatus
    set -lx __fish_last_status $status # Export for __fish_print_pipestatus.
    set -l normal (set_color --reset)

    # Colour the prompt differently when we're root
    set -l color_cwd $fish_color_cwd
    set -l suffix '>'
    if functions -q fish_is_root_user; and fish_is_root_user
        if set -q fish_color_cwd_root
            set color_cwd $fish_color_cwd_root
        end
        set suffix '#'
    end

    # --- environment awareness -------------------------------------------
    # Recolour user@host instead of showing a "(name)" prefix:
    #   purple = python venv, blue = nix shell, both = one of each.
    set -l color_user $fish_color_user
    set -l color_host $fish_color_host
    if set -q VIRTUAL_ENV
        set color_user a855f7
        set color_host a855f7
    end
    # nix-shell and `nix develop` export IN_NIX_SHELL; plain `nix shell`
    # exports nothing, so the `nix` wrapper function tags it instead.
    if set -q IN_NIX_SHELL; or set -q __IN_NIX_SHELL_CMD
        set color_host 2563eb
        set -q VIRTUAL_ENV; or set color_user 2563eb
    end
    # --------------------------------------------------------------------

    # Write pipestatus
    # If the status was carried over (if no command is issued or if `set` leaves the status untouched), don't bold it.
    set -l bold_flag --bold
    set -q __fish_prompt_status_generation; or set -g __fish_prompt_status_generation $status_generation
    if test $__fish_prompt_status_generation = $status_generation
        set bold_flag
    end
    set __fish_prompt_status_generation $status_generation
    set -l status_color (set_color $fish_color_status)
    set -l statusb_color (set_color $bold_flag $fish_color_status)
    set -l prompt_status (__fish_print_pipestatus "[" "]" "|" "$status_color" "$statusb_color" $last_pipestatus)

    echo -n -s (set_color $color_user) $USER $normal @ (set_color $color_host) (prompt_hostname) $normal ' ' \
        (set_color $color_cwd) (prompt_pwd) $normal (fish_vcs_prompt) $normal " "$prompt_status $suffix " "
end
