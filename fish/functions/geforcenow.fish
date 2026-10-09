function geforcenow --wraps='env -u LANG -u LC_ALL flatpak run com.nvidia.geforcenow' --description 'alias geforcenow=env -u LANG -u LC_ALL flatpak run com.nvidia.geforcenow'
    env -u LANG -u LC_ALL flatpak run com.nvidia.geforcenow $argv
end
