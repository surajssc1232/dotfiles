{ lib
, pkgs
, inputs
, ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./plymouth-title.nix
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

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    http-connections = 25;
    # Phone-hotspot DNS can take longer than 5s to answer, which made every
    # rebuild print "Resolving timed out" retries.
    connect-timeout = 15;
    # Uncommitted edits in ~/dotfiles are normal between rebuilds.
    warn-dirty = false;
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
  #
  # At boot, though, the greeter is skipped: initial_session logs suraj straight
  # into niri, and QS_LOCK_ON_START tells the desktop shell to raise its own
  # lock screen as soon as it starts. greetd runs initial_session once per boot
  # only, so logging out still lands on the greeter below. This gives up the
  # guarantee above: if the shell fails to start, the desktop is left unlocked.
  #
  # systemd-cat sends niri-session's output to the journal instead of tty1,
  # where systemctl's "Calling import-environment without a list of variable
  # names is deprecated" warning would otherwise show until niri draws.
  services.greetd = {
    enable = true;
    settings.initial_session = {
      command = "env QS_LOCK_ON_START=1 systemd-cat -t niri-session niri-session";
      user = "suraj";
    };
    settings.default_session = {
      command = "${pkgs.niri}/bin/niri -c /etc/greeter/niri.kdl";
      user = "greeter";
    };
  };

  # Autologin above never sees a password, so gnome-keyring stays locked and
  # Chromium-based browsers prompt for it. The desktop shell's lock screen
  # authenticates through the swaylock stack; hooking gnome-keyring in there
  # means the password typed at the boot lock screen unlocks the keyring too.
  security.pam.services.swaylock.enableGnomeKeyring = true;

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
    ensureDatabases = [ "taskdb" "suraj" ];
    ensureUsers = [{
      name = "suraj";
      ensureDBOwnership = true;
    }];
  };

  services.logind.settings = {
    Login = {
      HandlePowerKey = lib.mkForce "suspend";
      HandleLidSwitch = lib.mkForce "suspend";
      # Switching the monitor input briefly drops HDMI, which logind reads as
      # undocked. Without this, a closed lid suspends the laptop on every switch.
      HandleLidSwitchExternalPower = lib.mkForce "ignore";
      HandleLidSwitchDocked = lib.mkForce "ignore";
      LidSwitchIgnoreInhibited = lib.mkForce "yes";
    };
  };

  services.upower.ignoreLid = true;

  # Wake from suspend on a Wi-Fi magic packet (see ~/wake)
  systemd.services.wowlan = {
    description = "Enable Wake-on-WLAN";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${pkgs.iw}/bin/iw phy0 wowlan enable magic-packet";
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
    # The theme is a plain, dark spinner with a title, to sit closer to the
    # greeter that follows it than the vendor-logo default does. See
    # plymouth-title.nix.
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

  # Local DNS cache: a rebuild asks for cache.nixos.org thousands of times,
  # and without this every one of those went out to the upstream resolver.
  services.resolved.enable = true;

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
    BROWSER = "helium";
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
      "i2c"
    ];
  };

  # ddcutil talks to the monitor over i2c; this loads i2c-dev and creates the group.
  hardware.i2c.enable = true;

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
    # bindsTo stops this with keyd but never starts it again; wanting it from
    # keyd.service brings it back whenever keyd is (re)started.
    wantedBy = [ "multi-user.target" "keyd.service" ];

    serviceConfig = {
      Restart = "always";
      RestartSec = 1;

      ExecStart = pkgs.writeShellScript "keyd-layer-publish" ''
        set -u
        out="''${KEYD_LAYER_FILE:-/run/keyd-layers}"
        umask 022
        : > "$out"

        # keyd counts activations per layer: a toggle and a held overload
        # of the same layer stack, and it reports "+layer" on every step up
        # and "-layer" on every step down. So "-vim" from releasing the vim
        # overload does not mean vim is off while the toggle still holds it.
        # Count the same way, and drop a layer only when it reaches zero.
        declare -A count=()
        order=""

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

          n=''${count[$layer]:-0}
          case "$line" in
            +*) n=$((n + 1)) ;;
            -*) n=$((n > 0 ? n - 1 : 0)) ;;
          esac
          count[$layer]=$n

          # Entry order, for the label.
          case " $order " in
            *" $layer "*) ;;
            *) order="''${order:+$order }$layer" ;;
          esac

          active=""
          for l in $order; do
            [ "''${count[$l]}" -gt 0 ] && active="''${active:+$active }$l"
          done
          order="$active"

          printf '%s\n' "$active" > "$out.tmp" && mv -f "$out.tmp" "$out"
        done
      '';

      # A stale file would leave the bar claiming a layer is held after the
      # publisher is gone.
      ExecStopPost = "${pkgs.coreutils}/bin/rm -f /run/keyd-layers";
    };
  };

  services.keyd =
    let
      main = {
        capslock = "overload(vim, esc)";
        esc = "capslock";
        rightalt = "toggle(vim)";
        # The new keyboard has no right alt; its Copilot key sits there
        # instead and sends shift+meta+f23 as one press.
        "leftshift+leftmeta+f23" = "toggle(vim)";
      };
      layers = {
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
    in
    {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = layers // { inherit main; };
        };

        # The HS6209 wireless keyboard has no Fn lock, so its media row only
        # works with Fn held. This makes the icons the default and keeps real
        # F1-F12 one toggle away. A specific id wins over "*", so this config
        # carries the shared layers too. k: keeps it off the receiver's mouse.
        wireless = {
          ids = [ "k:32c2:0018" ];
          settings = layers // {
            main = main // {
              f1 = "config";
              f2 = "volumedown";
              f3 = "volumeup";
              f4 = "mute";
              f5 = "previoussong";
              f6 = "nextsong";
              f7 = "playpause";
              f8 = "stopcd";
              f9 = "homepage";
              f10 = "mail";
              f11 = "file";
              f12 = "calc";
            };
            # Ctrl+Caps (the caps key is Esc here) flips the row to real
            # F1-F12 and back. Fn+Caps can't: the keyboard sends it as a bare
            # capslock, same as caps alone.
            control = {
              capslock = "toggle(fkeys)";
            };
            fkeys = {
              f1 = "f1";
              f2 = "f2";
              f3 = "f3";
              f4 = "f4";
              f5 = "f5";
              f6 = "f6";
              f7 = "f7";
              f8 = "f8";
              f9 = "f9";
              f10 = "f10";
              f11 = "f11";
              f12 = "f12";
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


  # Terminal=true desktop entries and anything using xdg-terminal-exec open foot.
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "foot.desktop" ];
  };

  environment.systemPackages = with pkgs; [
    acpi
    yt-dlp
    foot
    nushell
    steam
    google-chrome
    prismlauncher
    uv
    chiaki-ng
    # Toggles the Dell between the laptop (HDMI 2) and the PS5 (HDMI 1).
    # If the current input can't be read, it goes to the laptop.
    (writeShellApplication {
      name = "monitor-switch";
      runtimeInputs = [ ddcutil libnotify ];
      text = ''
        laptop=0x12
        ps5=0x11

        current=$(ddcutil getvcp 60 --brief 2>/dev/null || true)
        if [[ $current == *x12* ]]; then
          target=$ps5
        else
          target=$laptop
        fi

        if ! ddcutil setvcp 60 "$target" --noverify; then
          notify-send "Monitor switch failed" "ddcutil could not set input $target"
          exit 1
        fi
      '';
    })
    # The Dell's brightness over DDC: up|down step 5% and show the shell's readout,
    # get|set are for the shell's slider. A key press that lands while the last
    # one is still running is dropped.
    (writeShellApplication {
      name = "monitor-brightness";
      runtimeInputs = [ ddcutil libnotify util-linux ];
      text = ''
        action=''${1:-}
        case "$action" in
          up) sign=1 ;;
          down) sign=-1 ;;
          get|set) ;;
          *) echo "usage: monitor-brightness up|down|get|set <value>" >&2; exit 1 ;;
        esac

        # Naming the bus skips ddcutil's scan of every display, about 1s per call.
        # The number can change between boots, so it's looked up each time.
        bus=""
        for connector in /sys/class/drm/card*-*; do
          case "$connector" in *eDP*|*LVDS*|*DSI*) continue ;; esac
          if [[ -e $connector/ddc && $(cat "$connector/status") == connected ]]; then
            bus=$(basename "$(readlink "$connector/ddc")")
            bus=''${bus#i2c-}
            break
          fi
        done

        if [[ -z $bus ]]; then
          if [[ $action == up || $action == down ]]; then
            notify-send "Monitor brightness" "No external monitor connected"
          fi
          exit 1
        fi

        case "$action" in
          get) exec ddcutil getvcp 10 --brief --bus "$bus" ;;
          set) exec ddcutil setvcp 10 "$2" --noverify --bus "$bus" ;;
        esac

        exec 9>"$XDG_RUNTIME_DIR/monitor-brightness.lock"
        flock -n 9 || exit 0

        reading=$(ddcutil getvcp 10 --brief --bus "$bus" 2>/dev/null || true)
        if [[ ! $reading =~ VCP\ 10\ C\ ([0-9]+)\ ([0-9]+) ]]; then
          notify-send "Monitor brightness failed" "ddcutil could not read the monitor"
          exit 1
        fi
        current=''${BASH_REMATCH[1]}
        max=''${BASH_REMATCH[2]}

        target=$(( current + sign * max * 5 / 100 ))
        (( target < 0 )) && target=0
        (( target > max )) && target=$max

        if ! ddcutil setvcp 10 "$target" --noverify --bus "$bus"; then
          notify-send "Monitor brightness failed" "ddcutil could not set brightness $target"
          exit 1
        fi

        qs ipc call osd monitorBrightness "$(( target * 100 / max ))" >/dev/null 2>&1 || true
      '';
    })
    streamlink
    claude-code
    efibootmgr
    efibooteditor
    ncdu
    nix-search-tv
    ffmpeg
    wineWow64Packages.waylandFull
    tealdeer
    nur.repos.Ev357.helium
    pkg-config
    ruff
    python3
    ninja
    swaybg
    umu-launcher
    meson
    wlsunset
    winetricks
    quickshell
    playerctl
    gnome-calculator
    gcc
    gdb
    zig
    rustup
    wireplumber
    btop
    fastfetch
    brightnessctl
    keyd
    wl-clipboard
    heroic
    libnotify
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
    pulseaudio
    lua
    ripgrep
    nil
    nixd
    unrar
    fd
    wf-recorder
    libva-utils
    pciutils
    mpv
    qbittorrent
    bat
    xwayland-satellite
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
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

  # Let the internal Intel Bluetooth adapter wake the laptop from suspend, so a
  # Bluetooth keyboard can wake it with the lid closed.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0aaa", ATTR{power/wakeup}="enabled"
  '';

  # The udev rule above gets reset to "disabled" after boot, so re-enable
  # wakeup right before every suspend. The xHCI root hubs (1d6b) must allow
  # wakeup too, or the 2.4 GHz keyboard/mouse receivers can't wake the laptop.
  powerManagement.powerDownCommands = ''
    for d in /sys/bus/usb/devices/*; do
      case "$(cat $d/idVendor 2>/dev/null):$(cat $d/idProduct 2>/dev/null)" in
        8087:0aaa|1d6b:0002|1d6b:0003|3554:fc03|32c2:0018)
          echo enabled > $d/power/wakeup ;;
      esac
    done
  '';

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
    options = "--delete-older-than 3d";
  };

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "weekly" ];
  nix.settings.auto-optimise-store = true;

}
