function nix-install-pkg -d "Install NixOS package by name"
    if test (count $argv) -eq 0
        echo "Usage: nix-install-pkg <package-name>"
        echo "Use tab completion to search packages"
        return 1
    end
    
    set -l pkg_name $argv[1]
    
    echo "Installing: $pkg_name"
    
    # Check if package already exists
    if grep -q "\\b$pkg_name\\b" /etc/nixos/configuration.nix
        echo "⚠ Package '$pkg_name' already in configuration"
        return 0
    end
    
    # Create timestamped backup
    set -l backup_file "/etc/nixos/configuration.nix.backup."(date +%Y%m%d_%H%M%S)
    sudo cp /etc/nixos/configuration.nix $backup_file
    echo "Backup created: $backup_file"
    
    # Add package to systemPackages
    sudo sed -i "/environment\.systemPackages.*with.*pkgs.*\[/a \    $pkg_name" /etc/nixos/configuration.nix
    
    echo "Added $pkg_name to configuration.nix"
    echo "Rebuilding NixOS..."
    
    # Rebuild and switch
    sudo nixos-rebuild switch
    
    if test $status -eq 0
        echo "✓ Successfully installed $pkg_name"
        sudo rm -f $backup_file
    else
        echo "✗ Build failed, restoring backup"
        sudo cp $backup_file /etc/nixos/configuration.nix
        return 1
    end
end
