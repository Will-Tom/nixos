# Boot dashboard: ghostty windows running the dash-*.sh scripts
{ config, pkgs, ... }:
let
  username = config.my.username;
in
{
  # dash-filesystem.sh reads btrfs stats
  security.sudo.extraRules = [{
    users = [ username ];
    commands = [
      { command = "/run/current-system/sw/bin/btrfs"; options = [ "NOPASSWD" ]; }
    ];
  }];

  home-manager.users.${username} = {
    home.file."bin/dash-updates.sh"     = { source = ./dashboard/dash-updates.sh;    executable = true; };
    home.file."bin/dash-filesystem.sh"  = { source = ./dashboard/dash-filesystem.sh; executable = true; };
    home.file."bin/dash-git.sh"         = { source = ./dashboard/dash-git.sh;        executable = true; };
    home.file."bin/dash-syncthing.sh"   = { source = ./dashboard/dash-syncthing.sh;  executable = true; };

    systemd.user.services.dashboard = {
      Unit = {
        Description = "Boot dashboard terminals";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [ "TERM_PROGRAM=ghostty" ];
        ExecStart = "${pkgs.writeShellScript "launch-dashboard" ''
          ${pkgs.ghostty}/bin/ghostty -e true &     # sacrificial: absorbs the startup signal
          sleep 1
          ${pkgs.ghostty}/bin/ghostty --title=dash-updates    -e /home/willisk/bin/dash-updates.sh &
          ${pkgs.ghostty}/bin/ghostty --title=dash-filesystem -e /home/willisk/bin/dash-filesystem.sh &
          ${pkgs.ghostty}/bin/ghostty --title=dash-git        -e /home/willisk/bin/dash-git.sh &
        ''}";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
