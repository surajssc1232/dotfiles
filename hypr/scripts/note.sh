#!/bin/bash

# Debug version of your file opener script with arrow key navigation
# This will log everything that happens

# Create log file
LOG_FILE="/tmp/note_script_debug.log"
echo "=== Script started at $(date) ===" >> "$LOG_FILE"
echo "PWD: $PWD" >> "$LOG_FILE"
echo "Terminal: $TERM" >> "$LOG_FILE"
echo "Display: $DISPLAY" >> "$LOG_FILE"
echo "Arguments: $@" >> "$LOG_FILE"

# Gruvbox color scheme (refined)
BG="#1d2021"      # Darker background for sleekness
FG="#ebdbb2"      # Cream foreground
ACCENT="#83a598"  # Soft blue accent
SELECT_BG="#458588" # Selection background
SELECT_FG="#1d2021" # Dark text on selection
BORDER="#504945"  # Subtle border
URGENT="#fb4934"  # Red for urgent/error

# Rofi configuration for sleek appearance with arrow key navigation
ROFI_CONFIG="
configuration {
    show-icons: true;
    disable-history: true;
    sidebar-mode: true;
    kb-row-down: \"Down\";
    kb-row-up: \"Up\";
    kb-accept-entry: \"Return\";
    kb-cancel: \"Escape\";
    kb-custom-1: \"Left\";
    kb-custom-2: \"Right\";
}

* {
    background-color: transparent;
    text-color: $FG;
    font: \"JetBrains Mono Nerd Font 13\";
}

window {
    background-color: $BG;
    border: 2px;
    border-color: $BORDER;
    border-radius: 0px;
    padding: 0;
    width: 50%;
    location: south;
    anchor: south;
    y-offset: -5%;
    transparency: \"real\";
}

mainbox {
    background-color: transparent;
    children: [ \"inputbar\", \"listview\" ];
    padding: 20px;
    spacing: 15px;
}

inputbar {
    background-color: rgba(40, 40, 40, 0.8);
    text-color: $FG;
    border: 1px;
    border-color: $ACCENT;
    border-radius: 0px;
    padding: 12px 16px;
    children: [ \"prompt\", \"entry\" ];
    spacing: 10px;
}

prompt {
    background-color: transparent;
    text-color: $ACCENT;
    font: \"JetBrains Mono Nerd Font Bold 13\";
}

entry {
    background-color: transparent;
    text-color: $FG;
    placeholder-color: rgba(235, 219, 178, 0.5);
    cursor-color: $ACCENT;
}

listview {
    background-color: transparent;
    columns: 1;
    lines: 12;
    cycle: true;
    dynamic: true;
    scrollbar: false;
    layout: vertical;
    reverse: false;
    fixed-height: true;
    spacing: 2px;
}

element {
    background-color: transparent;
    text-color: $FG;
    orientation: horizontal;
    border-radius: 0px;
    padding: 10px 16px;
    margin: 0px 0px;
    cursor: pointer;
}

element normal.normal {
    background-color: transparent;
    text-color: $FG;
}

element selected.normal {
    background-color: $SELECT_BG;
    text-color: $SELECT_FG;
    border: 1px;
    border-color: $ACCENT;
}

element alternate.normal {
    background-color: rgba(40, 40, 40, 0.2);
    text-color: $FG;
}

element-text {
    background-color: transparent;
    text-color: inherit;
    highlight: bold $ACCENT;
}
"

# Enhanced file icons using Nerd Font symbols
fzf_search() {
    local dir="$1"
    echo "FZF search called for directory: $dir" >> "$LOG_FILE"

    # Ultra-minimal fzf with gruvbox colors
    local selection=$(find "$dir" -type f -printf "%P\n" 2>/dev/null | \
            fzf --height=35% \
            --layout=reverse \
            --border=rounded \
            --margin=1 \
            --info=hidden \
            --prompt="▶ " \
            --pointer="●" \
            --no-scrollbar \
            --color="bg:#1d2021,fg:#ebdbb2,hl:#83a598" \
            --color="bg+:#458588,fg+:#1d2021,hl+:#1d2021" \
            --color="border:#504945,pointer:#fe8019,prompt:#83a598")

    echo "FZF selection: $selection" >> "$LOG_FILE"
    if [[ -n "$selection" ]]; then
        echo "$dir/$selection"
    fi
}

# Function to open a file
# Enhanced file opening function that works with Hyprland
open_file() {
    local file="$1"
    echo "=== OPENING FILE ===" >> "$LOG_FILE"
    echo "File: $file" >> "$LOG_FILE"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: File does not exist: $file" >> "$LOG_FILE"
        return 1
    fi

    echo "File exists: YES" >> "$LOG_FILE"
    echo "File readable: $(test -r "$file" && echo YES || echo NO)" >> "$LOG_FILE"
    echo "Terminal available: $TERM" >> "$LOG_FILE"
    echo "Display available: $DISPLAY" >> "$LOG_FILE"

    # Get file info
    local ext="${file##*.}"
    local filename=$(basename "$file")
    echo "File extension: $ext" >> "$LOG_FILE"
    echo "Filename: $filename" >> "$LOG_FILE"

    # Handle different file types
    case "$ext" in
        # Programming files - always open in nvim
        rs|py|js|ts|html|css|java|cpp|c|h|go|php|rb|lua|sh|bash|zsh|fish|vim|yaml|yml|json|xml|toml|ini|cfg|conf|md|txt)
            echo "Opening in nvim (programming/text file)" >> "$LOG_FILE"
            open_in_terminal_editor "$file"
            ;;
        # PDF files
        pdf)
            if command -v zathura >/dev/null 2>&1; then
                echo "Using zathura for PDF" >> "$LOG_FILE"
                zathura "$file" 2>/dev/null &
            else
                echo "Using xdg-open for PDF" >> "$LOG_FILE"
                xdg-open "$file" 2>/dev/null &
            fi
            ;;
        # Media files
        jpg|jpeg|png|gif|svg|ico|bmp|tiff|webp|mp4|mkv|avi|mov|mp3|flac|wav|ogg)
            echo "Using xdg-open for media file" >> "$LOG_FILE"
            xdg-open "$file" 2>/dev/null &
            ;;
        # Archives
        zip|rar|7z|tar|gz|bz2|xz)
            echo "Using xdg-open for archive" >> "$LOG_FILE"
            xdg-open "$file" 2>/dev/null &
            ;;
        # Everything else - try nvim first, fallback to xdg-open
        *)
            echo "Unknown extension, trying nvim first" >> "$LOG_FILE"
            if file "$file" | grep -q "text"; then
                open_in_terminal_editor "$file"
            else
                echo "Binary file, using xdg-open" >> "$LOG_FILE"
                xdg-open "$file" 2>/dev/null &
            fi
            ;;
    esac

    echo "File opening attempt completed" >> "$LOG_FILE"
}

# Function to open files in terminal editor (nvim)
open_in_terminal_editor() {
    local file="$1"
    echo "Opening in nvim (default for all non-media files)" >> "$LOG_FILE"

    if command -v nvim >/dev/null 2>&1; then
        echo "nvim found, attempting to open..." >> "$LOG_FILE"
        echo "Running: nvim '$file'" >> "$LOG_FILE"

        # Check if we're already in a proper terminal
        if [[ "$TERM" != "dumb" && -t 0 && -t 1 && -t 2 ]]; then
            echo "Proper terminal detected, opening directly" >> "$LOG_FILE"
            nvim "$file"
        else
            echo "No terminal detected, trying to open in new terminal" >> "$LOG_FILE"
            # Try different terminal emulators in order of preference
            if command -v alacritty >/dev/null 2>&1; then
                echo "Using alacritty" >> "$LOG_FILE"
                alacritty -e nvim "$file" &
            elif command -v kitty >/dev/null 2>&1; then
                echo "Using kitty" >> "$LOG_FILE"
                kitty nvim "$file" &
            elif command -v wezterm >/dev/null 2>&1; then
                echo "Using wezterm" >> "$LOG_FILE"
                wezterm start nvim "$file" &
            elif command -v foot >/dev/null 2>&1; then
                echo "Using foot" >> "$LOG_FILE"
                foot nvim "$file" &
            elif command -v gnome-terminal >/dev/null 2>&1; then
                echo "Using gnome-terminal" >> "$LOG_FILE"
                gnome-terminal -- nvim "$file" &
            else
                echo "No suitable terminal found, falling back to xdg-open" >> "$LOG_FILE"
                xdg-open "$file" 2>/dev/null &
            fi
        fi
    else
        echo "nvim not found, using xdg-open" >> "$LOG_FILE"
        xdg-open "$file" 2>/dev/null &
    fi
}

# Fixed get_file_icon function
get_file_icon() {
    local file="$1"
    local filename=$(basename "$file")
    local ext="${filename##*.}"
    local basename="${filename%.*}"

    # Handle directories first
    if [[ -d "$file" ]]; then
        # Special directory names
        case "$filename" in
            .git) echo "󰊢" ;; # Git icon
            .github) echo "󰊢" ;; # Git icon
            .vscode) echo "󰨞" ;; # VS Code icon
            node_modules) echo "󰎙" ;; # Node.js icon
            .config) echo "󰒓" ;; # Gear icon for config
            .cache) echo "󰁻" ;; # Box icon for cache
            .local) echo "󰋗" ;; # Folder with star
            bin) echo "󰆍" ;; # Binary icon
            lib) echo "󰆍" ;; # Binary icon
            src) echo "󰉋" ;; # Code icon
            docs|doc|documentation) echo "󰈙" ;; # Document icon
            assets|images|img) echo "󰈟" ;; # Image icon
            tests|test) echo "󰙨" ;; # Test tube icon
            build|dist|target) echo "󰐫" ;; # Hammer/build icon
            home|Home) echo "󰋗" ;; # Home folder icon
            Desktop) echo "󰋗" ;; # Desktop folder icon
            Documents) echo "󰈙" ;; # Documents folder icon
            Downloads) echo "󰣚" ;; # Download icon
            Pictures) echo "󰈟" ;; # Pictures folder icon
            Videos) echo "󰈫" ;; # Video icon
            Music) echo "󰎄" ;; # Music icon
            *) echo "󰉋" ;;  # Default folder icon
        esac
        return
    fi

    # Handle special filenames (exact matches)
    case "$filename" in
        # Version control
        .gitignore|.gitattributes|.gitmodules) echo "󰊢" && return ;; # Git icon

        # Package managers & build files
        package.json) echo "󰎙" && return ;; # Node.js icon
        package-lock.json) echo "󰎙" && return ;; # Node.js icon
        yarn.lock) echo "󰎙" && return ;; # Yarn icon
        Cargo.toml|Cargo.lock) echo "󱘗" && return ;; # Rust icon
        composer.json|composer.lock) echo "󰎐" && return ;; # PHP icon
        Gemfile|Gemfile.lock) echo "󰈞" && return ;; # Ruby icon
        requirements.txt|pyproject.toml|setup.py) echo "󰌠" && return ;; # Python icon
        go.mod|go.sum) echo "󰟓" && return ;; # Go icon
        Makefile|makefile|CMakeLists.txt) echo "󰐫" && return ;; # Build icon
        Dockerfile|docker-compose.yml|docker-compose.yaml) echo "󰡨" && return ;; # Docker icon

        # Config files
        .bashrc|.zshrc|.profile|.bash_profile) echo "󰘳" && return ;; # Terminal icon
        .vimrc|.nvimrc|init.vim|init.lua) echo "󰘫" && return ;; # Neovim icon
        .tmux.conf) echo "󰒓" && return ;; # Gear icon

        # Documentation
        README.md|README.txt|README) echo "󰈙" && return ;; # Document icon
        LICENSE|CHANGELOG.md|CHANGELOG) echo "󰈙" && return ;; # Document icon

        # Other special files
        .env|.env.local|.env.example) echo "󰗖" && return ;; # Key/secret icon
    esac

    # Handle file extensions
    case "$ext" in
        # Programming Languages
        html|htm) echo "󰌝" ;; # HTML icon
        css|scss|sass|less) echo "󰌜" ;; # CSS icon
        js|mjs) echo "󰌞" ;; # JavaScript icon
        ts) echo "󰛦" ;; # TypeScript icon
        jsx) echo "󰜈" ;; # React icon
        tsx) echo "󰜈" ;; # React TS icon
        vue) echo "󰡄" ;; # Vue.js icon
        svelte) echo "󰑣" ;; # Svelte icon
        php) echo "󰌟" ;; # PHP icon

        # JavaScript/Node ecosystem
        json) echo "󰘦" ;; # JSON icon

        # Python
        py|pyw|pyx) echo "󰌠" ;; # Python icon
        ipynb) echo "󰠠" ;; # Jupyter notebook icon

        # Rust
        rs) echo "󱘗" ;; # Rust icon

        # Go
        go) echo "󰟓" ;; # Go icon

        # C/C++
        c) echo "󰙱" ;; # C icon
        cpp|cc|cxx|c++) echo "󰙲" ;; # C++ icon
        h|hpp|hxx|h++) echo "󰙱" ;; # Header icon

        # Java/JVM
        java) echo "󰬷" ;; # Java icon
        kt|kts) echo "󱈙" ;; # Kotlin icon
        scala) echo "󰈸" ;; # Scala icon
        groovy) echo "󰈸" ;; # Groovy icon
        class|jar) echo "󰬷" ;; # Jar icon

        # .NET
        cs) echo "󰌛" ;; # C# icon
        vb) echo "󰈜" ;; # Visual Basic icon
        fs|fsx) echo "󰈷" ;; # F# icon

        # Other languages
        rb) echo "󰴭" ;; # Ruby icon
        lua) echo "󰢱" ;; # Lua icon
        vim) echo "󰕷" ;; # Vim icon
        sh|bash|zsh|fish) echo "󰒓" ;; # Shell script icon
        ps1|psm1) echo "󰨊" ;; # PowerShell icon
        pl|pm) echo "󰌟" ;; # Perl icon
        r|R) echo "󰟔" ;; # R icon
        matlab|m) echo "󰕮" ;; # Matlab icon
        swift) echo "󰛥" ;; # Swift icon
        dart) echo "󰻀" ;; # Dart icon
        elm) echo "󰘬" ;; # Elm icon
        haskell|hs) echo "󰘾" ;; # Haskell icon
        clj|cljs|cljc) echo "󰌠" ;; # Clojure icon

        # Data & Config
        xml) echo "󰗀" ;; # XML icon
        yaml|yml) echo "󰈈" ;; # YAML icon
        toml) echo "󰈈" ;; # TOML icon
        ini|cfg|conf) echo "󰒓" ;; # Config icon
        sql) echo "󰆼" ;; # SQL icon
        db|sqlite|sqlite3) echo "󰆼" ;; # Database icon
        csv) echo "󰈙" ;; # CSV icon

        # Documents
        md|markdown) echo "󰍔" ;; # Markdown icon
        txt) echo "󰈙" ;; # Text file icon
        rtf) echo "󰈙" ;; # Rich text file icon
        tex|latex) echo "󰙩" ;; # LaTeX icon
        pdf) echo "󰈦" ;; # PDF icon

        # Office documents
        doc|docx) echo "󰈬" ;; # Word icon
        xls|xlsx) echo "󰈛" ;; # Excel icon
        ppt|pptx) echo "󰈧" ;; # PowerPoint icon

        # Images
        jpg|jpeg|png|gif|svg|ico|icon|bmp|tiff|tif|webp|psd|ai|sketch) echo "󰈟" ;; # Image icon

        # Videos
        mp4|m4v|mkv|webm|avi|mov|wmv|flv|mpg|mpeg|m2v) echo "󰈫" ;; # Video icon

        # Audio
        mp3|flac|wav|aac|ogg|wma|m4a) echo "󰈣" ;; # Audio icon

        # Archives
        zip|rar|7z|tar|tgz|gz|bz2|xz) echo "󰀼" ;; # Archive icon
        deb|rpm|pkg) echo "󰏖" ;; # Package icon
        dmg|iso) echo "󰋊" ;; # Disk image icon

        # Fonts
        ttf|otf|woff|woff2|eot) echo "󰛖" ;; # Font icon

        # Executables & Binaries
        exe|msi|app|bin|run|AppImage) echo "󰐊" ;; # Executable icon

        # Logs & Temporary
        log) echo "󰌱" ;; # Log icon
        tmp|temp|cache) echo "󰃨" ;; # Temp icon
        bak|backup|old) echo "󰁯" ;; # Backup icon

        # Security & Keys
        key|pem|crt|cert|p12|pfx|gpg|asc|sig) echo "󰌋" ;; # Key icon

        # Game files
        unity|unitypackage) echo "󰚯" ;; # Unity icon
        blend|blend1) echo "󰂫" ;; # Blender icon

        # Lock files
        lock) echo "󰌾" ;; # Lock icon

        # Default for unknown extensions
        *)
            # Check if file is executable
            if [[ -x "$file" ]]; then
                echo "󰐊" # Executable icon
            else
                echo "󰈙"  # Generic file icon
            fi
            ;;
    esac
}

# Get current directory or use home if not set
CURRENT_DIR="${PWD:-$HOME}"
echo "Starting directory: $CURRENT_DIR" >> "$LOG_FILE"

# Build enhanced file list with icons and formatting
build_file_list() {
    local dir="$1"
    echo "Building file list for: $dir" >> "$LOG_FILE"

    # Add parent directory option if not in root
    if [[ "$dir" != "/" && "$dir" != "$HOME" ]]; then
        echo "󰉍 .." # Icon for parent directory
    fi

    # List directories first with sorting
    while IFS= read -r -d '' item; do
        local basename=$(basename "$item")
        local icon=$(get_file_icon "$item")
        echo "$icon $basename"
    done < <(find "$dir" -maxdepth 1 -type d ! -path "$dir" -print0 2>/dev/null | sort -z)

    # Then list files with icons
    while IFS= read -r -d '' item; do
        local basename=$(basename "$item")
        local icon=$(get_file_icon "$item")
        echo "$icon $basename"
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
}

# Function to handle navigation based on current selection
handle_navigation() {
    local action="$1"
    local selection="$2"
    local current_dir="$3"
    
    echo "Navigation action: $action, Selection: '$selection'" >> "$LOG_FILE"
    
    # Remove icon and extra spaces from selection
    local clean_selection=$(echo "$selection" | sed 's/^[^ ]* *//')
    echo "Clean selection: '$clean_selection'" >> "$LOG_FILE"
    
    case "$action" in
        "go_back"|"left")
            # Go to parent directory (same as selecting ..)
            if [[ "$current_dir" != "/" ]]; then
                echo "$(dirname "$current_dir")"
            else
                echo "$current_dir"
            fi
            ;;
        "enter"|"right"|"open")
            # Enter directory or open file
            if [[ "$clean_selection" == ".." ]]; then
                if [[ "$current_dir" != "/" ]]; then
                    echo "$(dirname "$current_dir")"
                else
                    echo "$current_dir"
                fi
            else
                local full_path="$current_dir/$clean_selection"
                if [[ -d "$full_path" ]]; then
                    echo "$full_path"
                elif [[ -f "$full_path" ]]; then
                    echo "OPEN_FILE:$full_path"
                else
                    echo "$current_dir"
                fi
            fi
            ;;
        *)
            echo "$current_dir"
            ;;
    esac
}

echo "Creating rofi config..." >> "$LOG_FILE"
# Create temporary rofi config file
TEMP_CONFIG=$(mktemp)
echo "$ROFI_CONFIG" > "$TEMP_CONFIG"
echo "Rofi config created at: $TEMP_CONFIG" >> "$LOG_FILE"

echo "Starting main loop..." >> "$LOG_FILE"
# Main loop with enhanced UX and arrow key navigation
while true; do
    # Create elegant prompt with current directory
    CURRENT_BASENAME=$(basename "$CURRENT_DIR")
    if [[ "$CURRENT_DIR" == "$HOME" ]]; then
        PROMPT="󰋗 ~" # Home icon for home directory
    else
        PROMPT="󰉍 $CURRENT_BASENAME" # Folder icon for current directory
    fi

    echo "Showing rofi with prompt: $PROMPT" >> "$LOG_FILE"

    # Show rofi with custom config
    SELECTION=$(build_file_list "$CURRENT_DIR" | rofi \
            -dmenu \
            -i \
            -p "$PROMPT" \
            -theme "$TEMP_CONFIG" \
            -markup-rows \
            -no-custom \
            -cycle)

    # Handle rofi exit codes
    EXIT_CODE=$?
    echo "Rofi exit code: $EXIT_CODE" >> "$LOG_FILE"
    echo "Selection: '$SELECTION'" >> "$LOG_FILE"

    case $EXIT_CODE in
        0)  # Normal selection (Enter)
            if [[ -z "$SELECTION" ]]; then
                echo "Empty selection, exiting" >> "$LOG_FILE"
                rm -f "$TEMP_CONFIG"
                exit 0
            fi
            
            # Handle enter key - navigate into directory or open file
            RESULT=$(handle_navigation "enter" "$SELECTION" "$CURRENT_DIR")
            if [[ "$RESULT" == OPEN_FILE:* ]]; then
                FILE_TO_OPEN="${RESULT#OPEN_FILE:}"
                echo "Opening file: $FILE_TO_OPEN" >> "$LOG_FILE"
                open_file "$FILE_TO_OPEN"
                rm -f "$TEMP_CONFIG"
                exit 0
            else
                CURRENT_DIR="$RESULT"
                echo "New directory: $CURRENT_DIR" >> "$LOG_FILE"
            fi
            ;;
        1)  # Escape - exit
            echo "Exit requested" >> "$LOG_FILE"
            rm -f "$TEMP_CONFIG"
            exit 0
            ;;
        10) # Custom key 1 (Left Arrow) - go back
            echo "Left arrow pressed - going back" >> "$LOG_FILE"
            if [[ "$CURRENT_DIR" != "/" ]]; then
                CURRENT_DIR=$(dirname "$CURRENT_DIR")
                echo "New directory (back): $CURRENT_DIR" >> "$LOG_FILE"
            fi
            ;;
        11) # Custom key 2 (Right Arrow) - enter/open
            if [[ -n "$SELECTION" ]]; then
                echo "Right arrow pressed - entering/opening" >> "$LOG_FILE"
                RESULT=$(handle_navigation "right" "$SELECTION" "$CURRENT_DIR")
                if [[ "$RESULT" == OPEN_FILE:* ]]; then
                    FILE_TO_OPEN="${RESULT#OPEN_FILE:}"
                    echo "Opening file: $FILE_TO_OPEN" >> "$LOG_FILE"
                    open_file "$FILE_TO_OPEN"
                    rm -f "$TEMP_CONFIG"
                    exit 0
                else
                    CURRENT_DIR="$RESULT"
                    echo "New directory: $CURRENT_DIR" >> "$LOG_FILE"
                fi
            fi
            ;;
        *)  # Other exit codes
            echo "Unknown exit code: $EXIT_CODE, exiting" >> "$LOG_FILE"
            rm -f "$TEMP_CONFIG"
            exit 0
            ;;
    esac
done

# Cleanup
echo "Cleaning up..." >> "$LOG_FILE"
rm -f "$TEMP_CONFIG"
echo "=== Script ended at $(date) ===" >> "$LOG_FILE"
