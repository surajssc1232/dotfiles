function nix-install-pkg-refresh -d "Refresh nix package completion cache"
    set -l cache_file ~/.cache/nix-install-pkg-completions.txt
    mkdir -p (dirname $cache_file)
    
    echo "🔄 Refreshing package cache..."
    
    nix-search-tv print | while read -l line
        set -l pkg_name (string split "/" $line)[-1] | string trim
        set -l source "nixpkgs"
        
        if string match -q "*nur*" $line
            set source "NUR"
        end
        
        echo -e "$pkg_name\t$source"
    end > $cache_file
    
    echo "✅ Cache refreshed: $cache_file"
    echo "📦 Total packages: "(wc -l < $cache_file)
end

