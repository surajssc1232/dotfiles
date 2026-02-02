function play_sound
    set type $argv[1]

    if command -q paplay
        # Generate tone with sox and pipe to paplay
        if command -q sox
            if test "$type" = plug
                sox -n -t wav - synth 0.2 sine 880 pad 0 0.1 | paplay 2>/dev/null &
            else
                sox -n -t wav - synth 0.2 sine 440 pad 0 0.1 | paplay 2>/dev/null &
            end
        else if command -q speaker-test
            # Fallback to speaker-test
            if test "$type" = plug
                speaker-test -t sine -f 880 -l 1 >/dev/null 2>&1 &
            else
                speaker-test -t sine -f 440 -l 1 >/dev/null 2>&1 &
            end
        end
    else
        echo -e "\a"
    end
end
