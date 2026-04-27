{ pkgs,lib,... }: # You can add more args like inputs if needed

{
  # --- Required basics ---
  home.username = "suraj"; # Replace with your actual username
  home.homeDirectory = "/home/suraj";
   
  home.pointerCursor = {
    name = "capitaine-cursors-white";
    package = pkgs.capitaine-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };


  xdg.mimeApps.enable = true; # Ensure this is set to true
  xdg.mimeApps.defaultApplications = {
    "application/x-bittorrent" = "org.qbittorrent.qBittorrent.desktop";
    "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";
  };
  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  # --- Example: Dark GTK theme (from your earlier questions) ---
  gtk = {
    enable = true;

    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };

    iconTheme = {
      package = pkgs.tela-icon-theme;
      name = "Tela-pink-dark"; # Or Tela-circle-dark, Tela-purple, etc.
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  # --- Important: Match your NixOS version ---
  home.stateVersion = "25.05"; # Or whatever your unstable channel uses

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style = {
      name="adwaita-dark";
      package = pkgs.adwaita-qt6;
    };
  };


  home.sessionVariables = {
    EDITOR=lib.mkForce "hx";
    QT_STYLE_OVERRIDE = lib.mkForce "adwaita-dark";
    QT_QPA_PLATFORMTHEME = lib.mkForce "adwaita";
    QT_QPA_PLATFORM = lib.mkForce "adwaita";
  };

  
  programs.neovim = {
    enable = true;
  };

  home.packages = with pkgs; [
    adwaita-qt
    adwaita-qt6
  ];

  xdg.configFile."gtk-3.0/settings.ini".force = true;

}

