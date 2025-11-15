#Edit this configuration file to define what should be installed on your system.  Help is available in the configuration.nix(5) man page and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs,inputs,system, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

	programs.git = {
  enable = true;
  config = {
    credential.helper = "store";
  	};
	};


  # Enable hardware acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      	intel-media-driver  # For Tiger Lake and newer Intel GPUs
        vulkan-loader	
    	vulkan-validation-layers
      	libvdpau-va-gl
    ];
  };

  programs.fish.enable=true;
  users.defaultUserShell = pkgs.fish;


  # nix-ld
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add common libraries that pre-compiled binaries might need
    stdenv.cc.cc.lib
    zlib
    openssl
    curl
    glib
    glibc
    libgcc
  ];
	

  # Bootloader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.systemd-boot.configurationLimit = 5;

 # Bootloader section
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
      useOSProber = true;
      configurationLimit = 5;
      # Add these to hide GRUB completely
      splashImage = null;  # Remove the background image
      backgroundColor = "#000000";  # Black background
      gfxmodeEfi = "1920x1080";
    };

    efi = {
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot";
    };
  };



# Auto-login moved to top-level displayManager
# services.displayManager.autoLogin = {
#   enable = true;
#   user = "suraj";
# };
services.libinput.enable=true;


  # Add these lines AFTER the boot.loader section
  boot.kernelParams = [ 
     "video=1920x1080"
     "quiet"           # Hides most boot messages
     "loglevel=3"      # Only show errors (3) or critical (2)
     "systemd.show_status=false"  # Hide systemd status messages
     "rd.udev.log_level=0"        # Reduce udev log verbosity
     "vt.global_cursor_default=0"
     "rd.systemd.show_status=false"
  ];

  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.initrd.kernelModules = [ "i915" ];
  # boot.plymouth.enable = true;

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
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
    LIBVA_DRIVER_NAME = "iHD";  # Use iHD for intel-media-driver
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.suraj = {
    isNormalUser = true;
    description = "suraj";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

services.keyd = {
  enable = true;
  keyboards = {
    default = {
      ids = ["*"];
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

  services.displayManager.ly.enable=true;
  services.power-profiles-daemon.enable=true;
  
  services.dbus.enable=true;
  services.dbus.packages = [pkgs.playerctl];
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  nixpkgs.overlays = [
    inputs.nur.overlays.default  # This exposes all NUR repos
  ];

  programs.mango.enable=true;
  programs.tmux.enable=true;
  programs.steam = {
		enable = true;
		extraCompatPackages = [pkgs.proton-ge-bin];
  };




  environment.systemPackages = with pkgs; [
		acpi
		i3status
		ninja
		fish
		meson
		nix-direnv
		direnv
		wlsunset
		git
		winetricks
		playerctl
		dbus
		waybar-mpris
		helix
		starship
		nnn
		google-chrome
		steam
		neovim
		libva
		fuzzel
		waybar
		libsForQt5.qt5.qtgraphicaleffects  # Required for themes
		libsForQt5.qt5.qtquickcontrols2
		ly
		foot
		btop
		fastfetch
		brightnessctl
		keyd
		wl-clipboard
		zsh
		heroic
		grim
		rustc
		cargo
		gcc
		rustfmt
		clippy
		slurp
		dunst
		libnotify
		swaybg
		zoxide
		lxappearance
		adw-gtk3
		hyprpicker
		bluez
		bluez-tools
		gcc
		clang
		fzf
		unzip
		cmake
		pkg-config
		niri
		jq
		pyright
		rust-analyzer
		pavucontrol
		nur.repos.Ev357.helium
		gnumake
		power-profiles-daemon
		clang-tools
		lua-language-server
		lua
		ripgrep
		unrar
		fd
		clippy
		dxvk
		wl-screenrec
		wf-recorder
		libva-utils  # Provides vainfo command
		pciutils     # Provides lspci command
		mpv
		qbittorrent
		nix-search-tv
		wineWowPackages.stable
		bat
		fish-lsp
    ghostty
    bibata-cursors
    capitaine-cursors-themed
    quickshell
    rustlings
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    nemo
  ]++[inputs.zen-browser.packages."${system}".default];


  fonts.packages = with pkgs;[
  			nerd-fonts.jetbrains-mono
        nerd-fonts.iosevka-term
				nerd-fonts.iosevka
				nerd-fonts.fira-code
				nerd-fonts.space-mono
  ];

  # environment.variables = {
  #   XCURSOR_THEME = "Bibata-Modern-Ice";
  #   XCURSOR_SIZE = "24";
  # };



  fonts.fontconfig.enable = true;

  qt.style = "adwaita-dark";

  fileSystems."/home/suraj/D:"={
	device = "/dev/disk/by-uuid/582d78bd-435f-4bca-8c4b-4bee046b5725";
	fsType = "ext4";
	options = ["nofail"];
  };

  hardware.graphics.enable32Bit = true;

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
  # services.openssh.enable = true;

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
  programs.zoxide.flags = ["--no-cmd" "--cmd j"];

  nix.gc = {
		automatic = true;
		dates = "weekly";
		options = "--delete-generations +5";
  };
}
