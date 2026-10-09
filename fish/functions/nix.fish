# `nix shell` exports no marker of its own (unlike nix-shell / nix develop,
# which set IN_NIX_SHELL), so tag it here for fish_prompt to pick up.
function nix --wraps nix --description 'nix, marking `nix shell` subshells for the prompt'
    for arg in $argv
        switch $arg
            case '-*'
                continue
            case shell
                __IN_NIX_SHELL_CMD=1 command nix $argv
                return $status
            case '*'
                break
        end
    end
    command nix $argv
end
