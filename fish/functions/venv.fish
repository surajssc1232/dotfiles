# Toggle the project virtualenv. Also bound to ctrl-alt-d.
function venv --description 'Activate ./.venv, or deactivate the active venv'
    if set -q VIRTUAL_ENV
        deactivate
    else if test -f .venv/bin/activate.fish
        source .venv/bin/activate.fish
    else
        echo "venv: no .venv in "(pwd) >&2
        return 1
    end
end
