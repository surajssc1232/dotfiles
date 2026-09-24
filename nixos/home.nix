{ pkgs, lib, config, inputs, ... }: {
  imports = [
    ./nvim.nix
    ./helix.nix
  ];

  # --- System & Profile Basics ---
  home = {
    username = "suraj";
    homeDirectory = "/home/suraj";
    stateVersion = "25.05";
    
    packages = with pkgs; [
      adwaita-qt
      adwaita-qt6
    ];

    sessionVariables = {
      QT_STYLE_OVERRIDE = lib.mkForce "adwaita-dark";
      QT_QPA_PLATFORMTHEME = lib.mkForce "adwaita";
    };

    pointerCursor = {
      name = "capitaine-cursors-white";
      package = pkgs.capitaine-cursors;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
  };

  # --- Theming (GTK & QT) ---
  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    iconTheme = {
      package = pkgs.tela-icon-theme;
      name = "Tela-pink-dark";
    };
    # Silences the 26.05 GTK4 theme warning completely
    gtk4.theme = null; 
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt6;
    };
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # --- MIME & Applications ---
  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/x-bittorrent" = [ "org.qbittorrent.qBittorrent.desktop" ];
        "x-scheme-handler/magnet"   = [ "org.qbittorrent.qBittorrent.desktop" ];
        "video/mp4"                 = [ "mpv.desktop" ];
        "video/x-matroska"          = [ "mpv.desktop" ];
        "video/webm"                = [ "mpv.desktop" ];
        "video/ogg"                 = [ "mpv.desktop" ];
        "video/quicktime"           = [ "mpv.desktop" ];
        "video/x-msvideo"           = [ "mpv.desktop" ];
        "video/x-flv"               = [ "mpv.desktop" ];
      };
    };
    
    configFile = {
      "gtk-3.0/settings.ini".force = true;
      "mimeapps.list".force = true;
    };
  };

}
