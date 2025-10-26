# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs,inputs,system, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  # Select internationalisation properties.
  i18n.defaultLocale = "en_IN";

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

  services.keyd.enable=true;
  services.displayManager.ly.enable=true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget

  programs.mango.enable=true;

  programs.fish.enable = true;

  users.defaultUserShell = pkgs.fish;

  environment.systemPackages = with pkgs; [
	neovim
	git
	fuzzel
	waybar
	lemurs
	ly
	foot
	alacritty
	btop
	freshfetch
	fastfetch
	brightnessctl
    	keyd
	wl-clipboard
	fish
	nushell
	zsh
	heroic
	grim
	rustup
	slurp
	nemo
	swww
	tmux
	zoxide
	lutris
	lxappearance
	adw-gtk3
	bibata-cursors
	hyprpicker
	bluez
	bluez-tools

  ]++[inputs.zen-browser.packages."${system}".default];

  fonts.packages = with pkgs;[
  	nerd-fonts.jetbrains-mono
        nerd-fonts.iosevka-term
	nerd-fonts.iosevka
	nerd-fonts.fira-code
	nerd-fonts.space-mono

  ];

  # themeing 
  # programs.gtk.enable = true;
  # programs.gtk.cursorTheme.package = pkgs.bibata-cursors;
  # programs.gtk.cursorTheme.name = "Bibata-Modern-Ice";
  # programs.gtk.theme.package = pkgs.adw-gtk3;
  # programs.gtk.theme.name = "adw-gtk3";
  qt.style = "adwaita-dark";

  fileSystems."/home/suraj/D:"={
	device = "/dev/disk/by-uuid/582d78bd-435f-4bca-8c4b-4bee046b5725";
	fsType = "ext4";
	options = ["nofail"];
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

}
