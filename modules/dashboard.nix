# Dashboard: noctalia bar widgets for system updates, filesystem health and
# git backups (plugin in noctalia/plugins/dashboard). This module provides
# their backends:
#   ~/bin/dash-update        update preview / apply / discard (Updates widget)
#   ~/bin/dash-git-status    git + backup-unit status as JSON (Git widget)
#   dashboard-fs-status      root timer writing /run/dashboard/fs.json (Filesystem widget)
#   dashboard-apply          root nixos-rebuild switch, started by Accept
#                            (systemctl start goes through a polkit password prompt)
{ config, pkgs, ... }:
let
  username = config.my.username;
in
{
  systemd.tmpfiles.rules = [ "d /run/dashboard 0755 root root -" ];

  systemd.services.dashboard-fs-status = {
    description = "Write filesystem health JSON for the dashboard widget";
    path = with pkgs; [ btrfs-progs jq util-linux coreutils gawk gnugrep gnused findutils systemd ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${./dashboard/fs-status.sh}";
    };
  };
  systemd.timers.dashboard-fs-status = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "15min";
    };
  };

  systemd.services.dashboard-apply = {
    description = "Switch to the updated system (dashboard Accept button)";
    path = [ "/run/current-system/sw" ];
    environment = {
      HOME = "/root";
      # /etc/nixos is owned by the user, so nix's libgit2 refuses it as root
      # (sudo is exempt, a service isn't). Trust it for this service only.
      XDG_CONFIG_HOME = "${pkgs.writeTextDir "git/config" ''
        [safe]
        	directory = /etc/nixos
      ''}";
    };
    # Never restart this unit from inside the switch it is running
    restartIfChanged = false;
    stopIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "infinity";
    };
    script = ''
      nixos-rebuild switch --flake /etc/nixos#nixos > /run/dashboard/apply.log 2>&1
    '';
  };

  home-manager.users.${username} = {
    home.file."bin/dash-update"     = { source = ./dashboard/dash-update.sh; executable = true; };
    home.file."bin/dash-git-status" = { source = ./dashboard/git-status.sh;  executable = true; };
  };
}
