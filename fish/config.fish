if status is-interactive
    set fish_greeting
    fastfetch --config examples/9.jsonc

		# ${UserConfigDir}/fish/config.fish
		set -Ux CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense' # optional
		carapace _carapace | source


		zoxide init fish | source
		
		set -x NNN_OPTS d


		if type -q tmux
				if status is-interactive
						and test -z "$TMUX"
						and string match -qv "screen*" $TERM
						and string match -qv "tmux*" $TERM
								exec tmux
				end
		end

		alias hh "helix"
		alias hx "helix"


		# FZF default options (Fish)
		set -gx FZF_DEFAULT_OPTS "\
		--color=bg+:#202020,bg:#151515,spinner:#ffafaf,hl:#ff8700 \
		--color=fg:#dddddd,header:#ffaf5f,info:#ff8700,pointer:#ffafaf \
		--color=marker:#ff5f87,fg+:#c6b6ee,prompt:#ff8700,hl+:#ff8700 \
		--color=border:#151515 \
		--multi"

end

echo \n

# opencode
fish_add_path /home/suraj/.opencode/bin
