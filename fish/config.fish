if status is-interactive
# Commands to run in interactive sessions can go here

    # Let fish_prompt render the venv indicator itself instead of
    # activate.fish prepending a plain "(name) " to the prompt.
    set -gx VIRTUAL_ENV_DISABLE_PROMPT 1
end
fish_add_path ~/.local/bin
