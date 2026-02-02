{ pkgs, ... }: # You can add more args like inputs if needed

{
  # --- Required basics ---
  home.username = "suraj"; # Replace with your actual username
  home.homeDirectory = "/home/suraj";

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };


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
    enable = true; # Required to manage Qt settings


    # Makes Qt apps follow your GTK theme where possible (good integration)
    platformTheme.name = "adwaita"; # Or "gnome" for GNOME-like behavior
    style.name = "adwaita-dark";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  
  xdg.configFile."gtk-3.0/settings.ini".force = true;
  home.file.".icons/default/index.theme".force = true;

  
}
