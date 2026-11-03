{ pkgs, ... }:

let
  sync = pkgs.writeShellApplication {
    name = "dotfiles-sync";
    runtimeInputs = with pkgs; [ coreutils git gnugrep libnotify rsync ];
    text = builtins.readFile ./scripts/dotfiles-sync.sh;
  };
in
{
  # Keeps the GitHub repo current with the live configs.
  home.packages = [ sync ];

  systemd.user.services.dotfiles-sync = {
    Unit.Description = "Commit and push changed dotfiles";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/dotfiles-sync";
    };
  };

  systemd.user.timers.dotfiles-sync = {
    Unit.Description = "Sync dotfiles every 15 minutes";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
