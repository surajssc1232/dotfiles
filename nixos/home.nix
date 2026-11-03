{ pkgs, lib, config, inputs, ... }: {
  imports = [
    ./nvim.nix
    ./helix.nix
    ./dotfiles-sync.nix
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
      enable = true;
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
      name = "Tela-grey-dark";
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
        "x-scheme-handler/http"     = [ "helium.desktop" ];
        "x-scheme-handler/https"    = [ "helium.desktop" ];
        "x-scheme-handler/about"    = [ "helium.desktop" ];
        "x-scheme-handler/unknown"  = [ "helium.desktop" ];
        "text/html"                 = [ "helium.desktop" ];
        "application/xhtml+xml"     = [ "helium.desktop" ];
        "video/mp4"                 = [ "mpv.desktop" ];
        "video/x-matroska"          = [ "mpv.desktop" ];
        "video/webm"                = [ "mpv.desktop" ];
        "video/ogg"                 = [ "mpv.desktop" ];
        "video/quicktime"           = [ "mpv.desktop" ];
        "video/x-msvideo"           = [ "mpv.desktop" ];
        "video/x-flv"               = [ "mpv.desktop" ];
        # Newer shared-mime-info names: .mkv is reported as video/matroska
        # and .avi as video/avi, and without these xdg-open falls back to
        # whatever else claims them (Chrome, Stremio).
        "video/matroska"            = [ "mpv.desktop" ];
        "video/avi"                 = [ "mpv.desktop" ];
        "video/x-m4v"               = [ "mpv.desktop" ];
        "video/mpeg"                = [ "mpv.desktop" ];
        "video/x-ms-wmv"            = [ "mpv.desktop" ];
        "video/3gpp"                = [ "mpv.desktop" ];
        "video/mp2t"                = [ "mpv.desktop" ];
        "video/x-ogm+ogg"           = [ "mpv.desktop" ];
        "text/markdown"             = [ "leaf.desktop" ];
        "application/pdf"           = [ "leaf.desktop" ];
        "application/epub+zip"      = [ "leaf.desktop" ];
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "leaf.desktop" ];
      };
    };

    # leaf is a TUI and xdg-open ignores Terminal=true, so foot is launched
    # explicitly. leaf can't read .docx, so those are converted to a temporary
    # EPUB first. leaf itself comes from the nix profile (~/leaf flake).
    desktopEntries.leaf = {
      name = "Leaf";
      comment = "Read PDF, EPUB, Markdown and Word documents in the terminal";
      exec = let
        leaf-open = pkgs.writeShellScript "leaf-open" ''
          leaf=${config.home.homeDirectory}/.nix-profile/bin/leaf
          case "$1" in
            *.docx|*.DOCX)
              tmp=$(mktemp -d)
              trap 'rm -rf "$tmp"' EXIT
              name=$(basename "$1")
              epub="$tmp/''${name%.*}.epub"
              ${pkgs.pandoc}/bin/pandoc "$1" --epub-title-page=false -o "$epub" || { read -r; exit 1; }
              "$leaf" open "$epub"
              ;;
            *) exec "$leaf" open "$1" ;;
          esac
        '';
      in "${pkgs.foot}/bin/foot ${leaf-open} %f";
      terminal = false;
      categories = [ "Office" "Viewer" ];
      mimeType = [
        "text/markdown"
        "application/pdf"
        "application/epub+zip"
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      ];
    };
    
    configFile = {
      "gtk-3.0/settings.ini".force = true;
      "mimeapps.list".force = true;
    };
  };

}
