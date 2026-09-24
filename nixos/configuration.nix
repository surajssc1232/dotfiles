{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # 8GB RAM with no swap means any memory spike (Unreal Engine games under
  # Wine/DXVK routinely produce these) gets hard-killed by the OOM killer
  # instead of gracefully paging out. zram gives cheap headroom with no
  # disk space needed.
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  programs.git = {
    enable = true;
    config = {
      credential.helper = "cache";
    };
  };
  programs.localsend.enable = true;

  virtualisation.docker.enable = true;


  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-users = [
      "root"
      "suraj"
      "@wheel"
    ];

    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];

    http-connections = 25;
    connect-timeout = 5;
    download-attempts = 3;

  };

  hardware.xpadneo.enable = true;

  documentation = {
    enable = true;
    man = {
      enable = true;
      man-db.enable = true;
    };

    dev.enable = true;
  };

  nixpkgs.config.packageOverrides = pkgs: {
    bottles = pkgs.bottles.override {
      removeWarningPopup = true;
    };
  };

  # hardware.nvidia.open=true;

  # Enable hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
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
    terminal = "tmux-256color";
    clock24 = true; # Use 24-hour format
    escapeTime = 0;

    extraConfig = ''
      # Status bar configuration
      set -g status-position top
      set -g status-interval 1  # Update every second

      # Right side: battery and clock
      set -g status-right-length 50
      set -g status-right "#[fg=yellow]#(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo N/A)%% #[fg=white]| #[fg=green]%H:%M:%S #[fg=white]| #[fg=blue]%Y-%m-%d"

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

    # X11 / GL / Vulkan, needed for prebuilt Wine/Proton builds (Heroic,
    # Lutris) to load their graphics driver via dlopen at runtime.
    libx11
    libxext
    libxrandr
    libxinerama
    libxcursor
    libxi
    libxfixes
    libxrender
    libxcomposite
    libxdamage
    libxcb
    libGL
    libglvnd
    vulkan-loader
  ];

  # Bootloader section
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  # The boot menu counts down before it picks the default, and the NixOS
  # default for that countdown is 5 seconds — which is essentially the whole
  # 6.06s systemd attributes to "loader". One second still lets a keypress
  # catch the menu, which is what matters on NixOS: booting a previous
  # generation is the way back when a rebuild breaks the desktop.
  #
  # Set this to 0 for an instant boot with no way into the menu.
  boot.loader.timeout = 1;

  boot.loader.limine = {
    enable = true;
    style.backdrop = "282828";
    style.wallpapers = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
    maxGenerations = 3;
  };

  services.libinput.enable = true;
  services.timekpr.enable = true;
  services.displayManager.defaultSession = "niri";

  # Login is the shell's own screen rather than ly's TUI: greetd starts a bare
  # niri whose only job is to hold one layer-shell surface, and that surface is
  # a Quickshell config wearing the lock screen's face. This is the same shape
  # Noctalia and DankMaterialShell use for their greeters, and it is preferred
  # over autologin-plus-lock because greetd authenticates *before* the session
  # exists: a shell that fails to start leaves no way in, rather than an
  # unlocked desktop. It also keeps gnome-keyring unlocking at login, which an
  # autologin path would have broken.
  #
  # The greeter files live in /etc rather than ~/.config because this runs as
  # the unprivileged `greeter` user, which cannot read /home/suraj (0700).
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.niri}/bin/niri -c /etc/greeter/niri.kdl";
      user = "greeter";
    };
  };

  environment.etc."greeter/niri.kdl".source = ./greeter/niri.kdl;
  environment.etc."greeter/shell.qml".source = ./greeter/shell.qml;

  # Where the desktop shell leaves a copy of the wallpaper for the login
  # screen. The greeter cannot read /home/suraj (0700), so the picture has to
  # be handed out here; suraj owns the directory because the shell writes it,
  # and it is world-readable because the `greeter` user has to read it.
  #
  # An empty directory is fine: the greeter falls back to a flat colour.
  systemd.tmpfiles.rules = [
    "d /var/lib/quickshell-greeter 0755 suraj users -"
  ];

  # The display manager ships as Type=idle, which holds its ExecStart back
  # until systemd's job queue goes quiet so boot messages finish printing
  # first. Measured on this machine that is ~3.6s of pure waiting: the unit is
  # queued at 3.3s and does not actually run until 6.9s. Starting it as soon
  # as it is ready is the single biggest saving in the whole boot.
  #
  # The cost is that late boot messages can flicker over the greeter's first
  # frame, which is the thing Type=idle exists to prevent. Delete this line to
  # get the old behaviour back.
  #
  # Targets greetd directly rather than display-manager: greetd declares
  # display-manager.service as an alias of itself, and defining a unit under
  # that name here would collide with the alias instead of overriding it.
  systemd.services.greetd.serviceConfig.Type = lib.mkForce "simple";

  # The slowest unit on this machine at ~4.4s, spent waiting for a DHCP lease
  # nothing needs that early. It does not delay the login screen, but it does
  # hold up graphical.target. Only docker is ordered after network-online
  # here, and it brings up its own bridge regardless.
  systemd.services.NetworkManager-wait-online.enable = false;

  services.gvfs.enable = true;
  services.flatpak.enable = true;
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "taskdb" "suraj"];
    ensureUsers = [{
      name = "suraj";
      ensureDBOwnership = true;
    }];
  };

  services.logind.settings = {
    Login = {
      HandlePowerKey = lib.mkForce "suspend";
      HandleLidSwitch = lib.mkForce "suspend";
      HandleLidSwitchExternalPower = lib.mkForce "suspend";
      HandleLidSwitchDocked = lib.mkForce "ignore";
      LidSwitchIgnoreInhibited = lib.mkForce "yes";
    };
  };

  services.upower.ignoreLid = true;

  # Add these lines AFTER the boot.loader section
  boot.kernelParams = [
    "video=1920x1080"
    "quiet" # Hides most boot messages
    "loglevel=0" # Only show errors (3) or critical (2)
    "systemd.show_status=false" # Hide systemd status messages
    "rd.udev.log_level=0" # Reduce udev log verbosity
    "vt.global_cursor_default=0"
    "rd.systemd.show_status=false"
    "usbcore.autosuspend=-1"
    # Tells plymouth to draw; without it the splash never appears even when
    # plymouth itself is enabled.
    "splash"
  ];

  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.initrd.kernelModules = [ "i915" ];

  # A splash from the moment the kernel can draw until the greeter maps.
  #
  # quiet/loglevel=0 already silence the kernel, but they cannot stop the
  # console from being a console: the screen still flips between text mode and
  # graphics as the initrd hands over and again as the greeter's compositor
  # takes the display, and anything a userspace unit writes to /dev/console
  # lands on top. Plymouth holds one picture across all of it.
  #
  # i915 is already in initrd.kernelModules above, which is what lets the
  # splash start early rather than halfway through the boot.
  boot.plymouth = {
    enable = true;
    # Plain and dark, to sit closer to the greeter that follows it than the
    # vendor-logo default does.
    theme = "spinner";
  };

  # Plymouth quits at 7.12s and greetd starts at 7.12s, but the greeter's
  # compositor needs most of a second after that before it paints anything.
  # Plain `plymouth quit` tears the splash down and restores the text console
  # underneath it — which still holds everything printed before the splash
  # started at 0.85s — so that whole backlog reappears for about a second.
  #
  # --retain-splash leaves the last frame on the framebuffer instead, and it
  # stays there until the greeter's first frame replaces it.
  systemd.services.plymouth-quit.serviceConfig.ExecStart = [
    ""
    "-${pkgs.plymouth}/bin/plymouth quit --retain-splash"
  ];

  # The same console is exposed a second time at login, when the greeter's
  # compositor lets go of the display and the session's takes it. Plymouth is
  # long gone by then, so the only way that gap stays quiet is for there to be
  # nothing on the console to show. Cleared once, before the greeter starts.
  systemd.services.clear-console-text = {
    description = "Blank tty1 so VT hand-offs never show old boot text";
    wantedBy = [ "greetd.service" ];
    before = [ "greetd.service" ];
    after = [ "plymouth-quit.service" ];
    serviceConfig = {
      Type = "oneshot";
      # Written straight to the device rather than through this unit's stdout,
      # because a service with no TTYPath has nowhere for `clear` to land.
      ExecStart = pkgs.writeShellScript "clear-tty1" ''
        printf '\033[2J\033[3J\033[H' > /dev/tty1 || true
      '';
    };
  };

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

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
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "en_IN/UTF-8"
  ];

  # ========== ENVIRONMENT VARIABLES (FOR ALL SESSIONS) ==========
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD"; # Use iHD for intel-media-driver
    # Set here rather than in home.nix: fish never sources home-manager's
    # hm-session-vars.sh, so EDITOR from there never reached the shell.
    EDITOR = "hx";
  };

  environment.variables = {
    XDG_SOUND_THEME = "freedesktop";
  };

  environment.pathsToLink = [ "/share/sounds" ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.xserver.enable = true;
  services.xserver.excludePackages = [ pkgs.xorg-server ];
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
    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "input"
      "docker"
    ];
  };

  # keyd knows which layers are held down; nothing else does. `keyd listen` is
  # the daemon's own event stream: one line per change, "+layer", "-layer", or
  # "/layout" for a layout switch.
  #
  # Its socket is root-only and has to stay that way. `keyd bind` can install a
  # command() binding, and keyd runs those as root — so letting your own user
  # talk to that socket would hand any process you run a route to root. This
  # service reads the stream as root and publishes the active set to one
  # world-readable file instead. One direction only: nothing travels back
  # toward the daemon, and the bar never touches the socket.
  systemd.services.keyd-layer-publisher = {
    description = "Publish keyd layer state for the status bar";
    after = [ "keyd.service" ];
    bindsTo = [ "keyd.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Restart = "always";
      RestartSec = 1;

      ExecStart = pkgs.writeShellScript "keyd-layer-publish" ''
        set -u
        out="''${KEYD_LAYER_FILE:-/run/keyd-layers}"
        umask 022
        : > "$out"
        active=""

        ${pkgs.keyd}/bin/keyd listen | while IFS= read -r line; do
          case "$line" in
            /*) continue ;;
            +*) layer="''${line#+}" ;;
            -*) layer="''${line#-}" ;;
            *) continue ;;
          esac

          # The built-in modifier layers fire on every shift and every ctrl.
          # They are not what anyone means by "I am in a layer".
          case " shift control alt altgr meta " in
            *" $layer "*) continue ;;
          esac

          case "$line" in
            +*) case " $active " in
                  *" $layer "*) ;;
                  *) active="''${active:+$active }$layer" ;;
                esac ;;
            -*) new=""
                for l in $active; do
                  [ "$l" = "$layer" ] || new="''${new:+$new }$l"
                done
                active="$new" ;;
          esac

          printf '%s\n' "$active" > "$out.tmp" && mv -f "$out.tmp" "$out"
        done
      '';

      # A stale file would leave the bar claiming a layer is held after the
      # publisher is gone.
      ExecStopPost = "${pkgs.coreutils}/bin/rm -f /run/keyd-layers";
    };
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
  services.udev.packages = [ pkgs.game-devices-udev-rules ];

  services.power-profiles-daemon.enable = true;
  services.dbus.enable = true;
  services.dbus.packages = [ pkgs.playerctl ];

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    inputs.nur.overlays.default # This exposes all NUR repos

    # umu-launcher 1.4.0: _fetch_releases in umu/umu_proton.py hardcodes an
    # expectation of exactly 2 GitHub release assets, but GE-Proton now ships 4
    # (aarch64 + x86_64 of both the tarball and its .sha512sum). The count check
    # then fails, GE-Proton is never downloaded, and PROTONPATH is left empty:
    #   FileNotFoundError: Environment variable not set or is empty: PROTONPATH
    # Filter the asset list down to this machine's architecture first.
    (final: prev: {
      umu-launcher-unwrapped = prev.umu-launcher-unwrapped.overridePythonAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          sed -i 's/^\(\s*\)asset_max: int = 2$/\1asset_max: int = 2\n\1_skip_arch = "aarch64" if os.uname().machine == "x86_64" else "x86_64"\n\1assets = [a for a in assets if _skip_arch not in a["name"]]/' umu/umu_proton.py
          grep -q _skip_arch umu/umu_proton.py
        '';
      });
    })
  ];



  programs.niri.enable = true;


  environment.systemPackages = with pkgs; [
    acpi
    google-chrome
    activitywatch
    prismlauncher
    nushell
    uv
    chiaki-ng
    streamlink
    claude-code-bin
    efibootmgr
    efibooteditor
    ncdu
    nix-search-tv
    ffmpeg
    wineWow64Packages.waylandFull
    jetbrains.idea
    tealdeer
    any-nix-shell
    nur.repos.Ev357.helium
    libudev-zero
    pkg-config
    ruff
    python3
    waybar
    ninja
    swaybg
    umu-launcher
    meson
    wlsunset
    winetricks
    vulkan-loader
    quickshell
    playerctl
    starship
    gcc
    gdb
    zig
    rustup
    libva
    wireplumber
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtquickcontrols2
    btop
    fastfetch
    brightnessctl
    keyd
    wl-clipboard
    heroic
    libnotify
    lxappearance
    gtk3
    orchis-theme
    bluez
    bluez-tools
    fzf
    unzip
    cmake
    jq
    pavucontrol
    lutris
    gnumake
    xwayland
    nixpkgs-fmt
    nemo
    kdePackages.qtlanguageserver
    pulseaudio
    lua
    ripgrep
    matugen
    nil
    nixd
    unrar
    fd
    dxvk
    wl-screenrec
    wf-recorder
    libva-utils
    pciutils
    mpv
    qbittorrent
    bat
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    papirus-icon-theme
    xwayland-satellite
    bibata-cursors
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka-term
    nerd-fonts.shure-tech-mono
    gohufont
  ];

  fonts.fontconfig.enable = true;

  fileSystems."/home/suraj/D:" = {
    device = "/dev/disk/by-uuid/582d78bd-435f-4bca-8c4b-4bee046b5725";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  powerManagement.powertop.enable = false;

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

  # No SSH server: nothing logs in to this laptop remotely, and there are no
  # keys set up, so it was only ever offering password login on port 22.
  services.openssh.enable = false;

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
  programs.zoxide.flags = [
    "--no-cmd"
    "--cmd j"
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "weekly" ];

}
