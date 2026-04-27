function fp --description 'fzf with bat preview'
    fzf --preview "bat --color=always --style=numbers --line-range=:500 {}" $argv
    # $argv allows you to pass extra flags like 'fp -m' for multi-select
end
