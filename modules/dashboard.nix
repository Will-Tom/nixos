# Dashboard: noctalia bar widgets for system updates, filesystem health and
# git backups (plugin in noctalia/plugins/dashboard). This module provides
# their backends:
#   ~/bin/dash-update        update preview / apply / discard (Updates widget)
#   ~/bin/dash-git-status    git + backup-unit status as JSON (Git widget)
#   dashboard-fs-status      root timer writing /run/dashboard/fs.json (Filesystem widget)
#   dashboard-apply          root nixos-rebuild switch, started by Accept
#                            (systemctl start goes through a polkit password prompt)
# The old dash-*.sh terminal scripts are still installed to run by hand.
{ config, pkgs, ... }:
let
  username = config.my.username;
in
{
  # dash-filesystem.sh (run by hand) reads btrfs stats
  security.sudo.extraRules = [{
    users = [ username ];
    commands = [
      { command = "/run/current-system/sw/bin/btrfs"; options = [ "NOPASSWD" ]; }
    ];
  }];

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
    environment.HOME = "/root";
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

    home.file."bin/dash-updates.sh"    = { source = ./dashboard/dash-updates.sh;    executable = true; };
    home.file."bin/dash-filesystem.sh" = { source = ./dashboard/dash-filesystem.sh; executable = true; };
    home.file."bin/dash-git.sh"        = { source = ./dashboard/dash-git.sh;        executable = true; };
    home.file."bin/dash-syncthing.sh"  = { source = ./dashboard/dash-syncthing.sh;  executable = true; };
  };
}
