{ pkgs, ... }:

let
  # gotools ships a dozen binaries, one of which (modernize) collides with
  # gopls. We only want the Go formatter, so expose just that.
  goimports = pkgs.runCommand "goimports" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.gotools}/bin/goimports $out/bin/goimports
  '';
in
{
  programs.helix = {
    enable = true;
  };

  xdg.configFile."helix/config.toml".source = ./helix/config.toml;
  xdg.configFile."helix/languages.toml".source = ./helix/languages.toml;

  home.packages = with pkgs; [
    bash-language-server
    goimports
    lldb
  ];
}
