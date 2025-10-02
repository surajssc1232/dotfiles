if status is-interactive
    # Commands to run in interactive sessions can go here
		set fish_greeting
		fastfetch --config examples/9.jsonc
	
if type -q tmux
    if status is-interactive
        and test -z "$TMUX"
        and string match -qv "screen*" $TERM
        and string match -qv "tmux*" $TERM
            exec tmux
    end
end


end


echo \n
