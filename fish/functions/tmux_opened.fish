function tmux_opened
    if status is-interactive
        and not set -q TMUX
        and not set -q VSCODE_INJECTION
        set session_name "term-"(random)
        tmux new -s $session_name
    end
end
