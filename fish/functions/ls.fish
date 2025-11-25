function ls --wraps='eza --icons=always' --wraps='eza -a --icons=always' --wraps='eza -al --icons=always' --description 'alias ls eza -al --icons=always'
    eza -al --icons=always $argv
end
