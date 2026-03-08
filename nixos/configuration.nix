{ pkgs, inputs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  
  programs.git = {
    enable = true;
    config = {
      credential.helper = "store";
    };
  };

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
    ];
    trusted-users = [ "root" "suraj" "@wheel" ];

    trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];

    http-connections = 25;
    connect-timeout = 5;
    download-attempts = 3;
    
  };

  hardware.xpadneo.enable = true;

  documentation.enable = true;
  documentation.man.enable = true;
  documentation.man.cache.enable=true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
  };


  nixpkgs.config.packageOverrides = pkgs: {
    bottles = pkgs.bottles.override {
    removeWarningPopup = true;
    };
  };
  
  

  # Enable hardware acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # For Tiger Lake and newer Intel GPUs
      vulkan-loader
      vulkan-validation-layers
      libvdpau-va-gl
    ];
  };
  
  programs.fish.enable = true;
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  users.defaultUserShell = pkgs.fish;

  # nix-ld
  programs.nix-ld.enable = true;

programs.tmux = {
  enable = true;
  terminal = "screen-256color";
  clock24 = true;  # Use 24-hour format
  escapeTime =  0;

  
  extraConfig = ''
    # Status bar configuration
    set -g status-position top
    set -g status-interval 1  # Update every second

    # Right side: battery and clock
    set -g status-right-length 50
    set -g status-right "#[fg=yellow]#(cat /sys/class/power_supply/BAT0/capacity)%% #[fg=white]| #[fg=green]%H:%M:%S #[fg=white]| #[fg=blue]%Y-%m-%d"
    
    # Left side: session name
    set -g status-left ""
    set -g status-left-length 0

    
    # Make status bar transparent
    set -g status-style bg=default,fg=white
    
    # Make pane borders transparent
    set -g pane-border-style fg=default
    set -g pane-active-border-style fg=cyan
    
    # Make window status transparent
    setw -g window-status-style bg=default,fg=white
    setw -g window-status-current-style bg=default,fg=cyan,bold
    
    # Prefix key configuration (commented out as in your config)
    # unbind C-b
    # set -g prefix C-a
    # bind M-a send-prefix
    
    # Create new window with Alt+c
    unbind C-c
    bind -n M-c new-window
    
    # Split panes using Alt+| and Alt+- without prefix
    bind -n M-\\ split-window -h  # Alt+\ (which appears as |)
    bind -n M-- split-window -v   # Alt+-
    
    # Switch panes using arrow keys without prefix
    bind -n M-Left select-pane -L
    bind -n M-Right select-pane -R
    bind -n M-Up select-pane -U
    bind -n M-Down select-pane -D
    
    # Switch windows using Shift+arrow without prefix
    bind -n S-Left previous-window
    bind -n S-Right next-window
    
    # Close current pane with Alt+x without prefix
    bind -n M-x kill-pane
  '';
};

    programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    curl
    glibc
    libgcc
  ];



  # Bootloader section
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.limine = {
    enable = true;
    style.backdrop = "282828";
    style.wallpapers = [];
    efiSupport = true;
    efiInstallAsRemovable = true;
    maxGenerations = 3;
  };
  
  services.libinput.enable = true;
  services.displayManager.ly.enable = true;
  services.displayManager.defaultSession = "niri";
  services.gvfs.enable = true;
  services.flatpak.enable = true;

  services.logind.settings = {
    Login = {
      HandlePowerKey = "suspend";
      HandleLidSwitch = "ignore";
    };
  };
  # Add these lines AFTER the boot.loader section
  boot.kernelParams = [
    "video=1920x1080"
    "quiet" # Hides most boot messages
    "loglevel=0" # Only show errors (3) or critical (2)
    "systemd.show_status=false" # Hide systemd status messages
    "rd.udev.log_level=0" # Reduce udev log verbosity
    "vt.global_cursor_default=0"
    "rd.systemd.show_status=false"
  ];
  
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.initrd.kernelModules = [ "i915" ];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  # Ensure UTF-8 support is available
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "en_IN/UTF-8" ];

  # ========== ENVIRONMENT VARIABLES (FOR ALL SESSIONS) ==========
  environment.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    LIBVA_DRIVER_NAME = "iHD"; # Use iHD for intel-media-driver
    # EDITOR = "hx";
  };

  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "14";
    EDITOR = "hx";
    XDG_SOUND_THEME="freedesktop";
  };

  environment.pathsToLink = ["/share/sounds"];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.xserver.enable = true;
  services.upower.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.suraj = {
    isNormalUser = true;
    description = "suraj";
    extraGroups = [ "networkmanager" "wheel" "audio" "input" ];
  };

  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "overload(vim, esc)";
            esc = "capslock";
            rightalt = "toggle(vim)";
            f5 = "macro(C-a C-c)";
          };
          vim = {
            h = "left";
            "[" = "{";
            "]" = "}";
            j = "down";
            k = "up";
            "C-w" = "C-w";
            "'" = ''"'';
            ";" = ":";
            "9" = "(";
            "0" = ")";
            "8" = "*";
            "\\" = "|";
            "," = "<";
            "." = ">";
            "C-l" = "C-l";
            l = "right";
            u = "esc";
            o = "A-left";
            p = "A-right";
            q = "C-f1";
            w = "C-f2";
            e = "C-f3";
          };
          bloodyroar = {
            i = "up";
            j = "left";
            k = "down";
            l = "right";
          };
        };
      };
    };
  };


  programs.gamemode.enable = true;
  services.udev.packages = [pkgs.game-devices-udev-rules];
  
  services.power-profiles-daemon.enable = true;
  # services.greetd = {
  #   enable = true;
  #   useTextGreeter = true;
  #   settings = {
  #     default_session = {
  #       command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
  #       user = "suraj";
  #     };
  #   }
  #   ;
  #   };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVDisallocate = true;
  };


  
  services.dbus.enable = true;
  services.dbus.packages = [ pkgs.playerctl ];

  # Allow unfree packages
  nixpkgs.config = {
      allowUnfree = true;
    };

  services.xserver.videoDrivers = [ "nvidia" "amdgpu" ];

  nixpkgs.overlays = [
    inputs.nur.overlays.default # This exposes all NUR repos
  ];

  programs.niri.enable = true;
  programs.mango.enable=true;

 
  environment.plasma6.excludePackages = with pkgs;[
    kdePackages.elisa
    kdePackages.dolphin
    kdePackages.kate
    kdePackages.kwallet
    kdePackages.kwalletmanager
    kdePackages.kwallet-pam
    kdePackages.kwrited
    kdePackages.okular
    kdePackages.ark
  ];

  
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [proton-ge-bin];
  };

  environment.systemPackages = with pkgs; [
    acpi
    wineWow64Packages.waylandFull
    bottles
    any-nix-shell
    pkgs.nur.repos.Ev357.helium
    libudev-zero
    pkg-config
    tuigreet
    gleam
    erlang
    ruff
    python3
    waybar
    ninja
    swaybg
    pulseaudio
    umu-launcher
    fish
    meson
    wlsunset
    git
    winetricks
    google-chrome
    playerctl
    dbus
    starship
    gcc
    zig
    rustup
    steam
    neovim
    libva
    fuzzel
    waybar
    wireplumber
    libsForQt5.qt5.qtgraphicaleffects # Required for themes
    libsForQt5.qt5.qtquickcontrols2
    direnv
    nix-direnv
    btop
    fastfetch
    brightnessctl
    keyd
    wl-clipboard
    tmux
    heroic
    grim
    cargo
    clippy
    slurp
    dunst
    libnotify
    zoxide
    lxappearance
    gtk3
    orchis-theme
    hyprpicker
    bluez
    bluez-tools
    fzf
    unzip
    cmake
    pkg-config
    niri
    jq
    pyright
    pavucontrol
    lutris
    gnumake
    xwayland
    nixpkgs-fmt
    power-profiles-daemon
    nemo
    steam-run
    kdePackages.qtlanguageserver
    clang-tools
    pulseaudio
    lua-language-server
    lua
    ripgrep
    matugen
    nil
    nixd
    unrar
    fd
    clippy
    dxvk
    wl-screenrec
    wf-recorder
    libva-utils # Provides vainfo command
    pciutils # Provides lspci command
    mpv
    qbittorrent
    nix-search-tv
    bat
    fish-lsp
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk    
    papirus-icon-theme
    xwayland-satellite
    bibata-cursors    
  ];



  fonts.packages = with pkgs;[
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka-term
  ];

  fonts.fontconfig.enable = true;

  fileSystems."/home/suraj/D:" = {
    device = "/dev/disk/by-uuid/582d78bd-435f-4bca-8c4b-4bee046b5725";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  hardware.graphics.enable32Bit = true;

  powerManagement.powertop.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  programs.zoxide.enable = true;
  programs.zoxide.flags = [ "--no-cmd" "--cmd j" ];

  nix.gc = {
    automatic = true;
    dates = "daily";
  };


  nix.settings.auto-optimise-store = true; 

}
