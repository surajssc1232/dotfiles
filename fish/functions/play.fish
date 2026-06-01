function play --description 'Stream a torrent link directly to MPV using peerflix'
    if test (count $argv) -eq 0
        echo "Error: Please provide a magnet link or torrent file path."
        return 1
    end

    peerflix $argv[1] --mpv
end

